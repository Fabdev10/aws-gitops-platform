variable "region" {
  description = "AWS region for production resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Base project name used for tagging and naming."
  type        = string
  default     = "aws-gitops-platform"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "VPC CIDR for production."
  type        = string
}

variable "az_count" {
  description = "Number of availability zones used by production."
  type        = number
  default     = 2
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs."
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener."
  type        = string
}

variable "app_port" {
  description = "Container and target group port."
  type        = number
  default     = 8080
}

variable "image_tag" {
  description = "Image tag deployed by ECS task definition."
  type        = string
  default     = "production"
}

variable "desired_count" {
  description = "Number of desired ECS tasks in production."
  type        = number
  default     = 2
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 1024
}

variable "secrets" {
  description = "Map of environment variable name to Secrets Manager ARN."
  type        = map(string)
  default     = {}
}
