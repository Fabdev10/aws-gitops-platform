terraform {
  required_version = "~> 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  name = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Networking foundation for ALB and ECS.
module "networking" {
  source = "../../modules/networking"

  name                 = local.name
  region               = var.region
  vpc_cidr             = var.vpc_cidr
  az_count             = var.az_count
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  app_port             = var.app_port
  tags                 = local.common_tags
}

# ECR repository that stores application images.
module "ecr" {
  source = "../../modules/ecr"

  repository_name = local.name
  tags            = local.common_tags
}

# ALB configured with HTTP to HTTPS redirect and ACM certificate.
module "alb" {
  source = "../../modules/alb"

  name                  = local.name
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.networking.alb_security_group_id
  certificate_arn       = var.certificate_arn
  target_port           = var.app_port
  health_check_path     = "/health"
  tags                  = local.common_tags
}

# ECS Fargate service that pulls secrets at runtime from Secrets Manager.
module "ecs" {
  source = "../../modules/ecs"

  name                  = local.name
  region                = var.region
  image_uri             = "${module.ecr.repository_url}:${var.image_tag}"
  container_name        = "app"
  container_port        = var.app_port
  health_check_path     = "/health"
  task_cpu              = var.task_cpu
  task_memory           = var.task_memory
  desired_count         = var.desired_count
  enable_autoscaling    = var.enable_autoscaling
  autoscaling_min_capacity = var.autoscaling_min_capacity
  autoscaling_max_capacity = var.autoscaling_max_capacity
  autoscaling_cpu_target   = var.autoscaling_cpu_target
  autoscaling_memory_target = var.autoscaling_memory_target
  private_subnet_ids    = module.networking.private_subnet_ids
  ecs_security_group_id = module.networking.ecs_security_group_id
  target_group_arn      = module.alb.target_group_arn
  secrets               = var.secrets
  enable_service_alarms            = var.enable_service_alarms
  alarm_cpu_utilization_threshold  = var.alarm_cpu_utilization_threshold
  alarm_memory_utilization_threshold = var.alarm_memory_utilization_threshold
  alarm_evaluation_periods         = var.alarm_evaluation_periods
  alarm_period_seconds             = var.alarm_period_seconds
  alarm_actions                    = var.alarm_actions
  tags                  = local.common_tags
}

output "ecr_repository_url" {
  description = "ECR URL to push images used by production deployment."
  value       = module.ecr.repository_url
}

output "alb_dns_name" {
  description = "Production ALB DNS name."
  value       = module.alb.alb_dns_name
}

output "ecs_cluster_name" {
  description = "Production ECS cluster name."
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Production ECS service name."
  value       = module.ecs.service_name
}
