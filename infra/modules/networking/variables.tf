variable "name" {
  description = "Project/environment name prefix."
  type        = string
}

variable "region" {
  description = "AWS region used to derive Availability Zones."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "az_count" {
  description = "How many AZs/subnet pairs to create."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 6
    error_message = "az_count must be between 2 and 6."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets; one per AZ."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == var.az_count
    error_message = "public_subnet_cidrs must match az_count."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets; one per AZ."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == var.az_count
    error_message = "private_subnet_cidrs must match az_count."
  }
}

variable "app_port" {
  description = "Container port exposed by ECS service."
  type        = number
  default     = 8080
}

variable "tags" {
  description = "Standard tags applied to all networking resources."
  type        = map(string)
  default     = {}
}
