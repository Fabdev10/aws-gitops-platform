terraform {
  required_version = "~> 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  # Build AZ names like us-east-1a/us-east-1b based on az_count.
  az_suffixes = slice(["a", "b", "c", "d", "e", "f"], 0, var.az_count)
  azs         = [for suffix in local.az_suffixes : "${var.region}${suffix}"]

  # Pair each subnet CIDR with an index for consistent naming/tags.
  public_subnets = {
    for idx, cidr in var.public_subnet_cidrs : idx => {
      cidr = cidr
      az   = local.azs[idx]
    }
  }

  private_subnets = {
    for idx, cidr in var.private_subnet_cidrs : idx => {
      cidr = cidr
      az   = local.azs[idx]
    }
  }

  default_tags = merge(var.tags, {
    Module = "networking"
  })
}

# Core VPC for the platform.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.default_tags, {
    Name = "${var.name}-vpc"
  })
}

# Internet Gateway allows public subnets to reach the Internet.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.default_tags, {
    Name = "${var.name}-igw"
  })
}

# Public subnets host ALB and NAT gateway.
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(local.default_tags, {
    Name = "${var.name}-public-${each.value.az}"
    Tier = "public"
  })
}

# Private subnets host ECS tasks.
resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(local.default_tags, {
    Name = "${var.name}-private-${each.value.az}"
    Tier = "private"
  })
}

# Elastic IP used by NAT Gateway.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.default_tags, {
    Name = "${var.name}-nat-eip"
  })
}

# NAT Gateway provides outbound Internet access for private subnets.
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["0"].id

  depends_on = [aws_internet_gateway.this]

  tags = merge(local.default_tags, {
    Name = "${var.name}-nat"
  })
}

# Route table for all public subnets.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.default_tags, {
    Name = "${var.name}-public-rt"
  })
}

# Default route from public subnets to Internet Gateway.
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# Associate each public subnet to the public route table.
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Route table for all private subnets.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.default_tags, {
    Name = "${var.name}-private-rt"
  })
}

# Default route from private subnets to NAT Gateway.
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

# Associate each private subnet to the private route table.
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# Security group for ALB, allowing inbound HTTP/HTTPS from the Internet.
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "ALB ingress/egress controls"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, {
    Name = "${var.name}-alb-sg"
  })
}

# Security group for ECS tasks, only allowing traffic from ALB on app_port.
resource "aws_security_group" "ecs_service" {
  name        = "${var.name}-ecs-sg"
  description = "ECS service ingress restricted to ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Allow app traffic from ALB SG"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, {
    Name = "${var.name}-ecs-sg"
  })
}
