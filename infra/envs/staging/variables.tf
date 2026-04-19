variable "region" {
  description = "AWS region for staging resources."
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
  default     = "staging"
}

variable "vpc_cidr" {
  description = "VPC CIDR for staging."
  type        = string
}

variable "az_count" {
  description = "Number of availability zones used by staging."
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
  default     = "staging"
}

variable "desired_count" {
  description = "Number of desired ECS tasks in staging."
  type        = number
  default     = 1
}

variable "enable_autoscaling" {
  description = "Enable ECS service autoscaling in staging."
  type        = bool
  default     = true
}

variable "autoscaling_min_capacity" {
  description = "Minimum ECS tasks in staging autoscaling policy."
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Maximum ECS tasks in staging autoscaling policy."
  type        = number
  default     = 3
}

variable "autoscaling_cpu_target" {
  description = "CPU target percentage for staging autoscaling."
  type        = number
  default     = 60
}

variable "autoscaling_memory_target" {
  description = "Memory target percentage for staging autoscaling."
  type        = number
  default     = 75
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "secrets" {
  description = "Map of environment variable name to Secrets Manager ARN."
  type        = map(string)
  default     = {}
}

variable "enable_service_alarms" {
  description = "Enable ECS CloudWatch alarms in staging."
  type        = bool
  default     = true
}

variable "alarm_cpu_utilization_threshold" {
  description = "CPU alarm threshold percentage for staging ECS service."
  type        = number
  default     = 80
}

variable "alarm_memory_utilization_threshold" {
  description = "Memory alarm threshold percentage for staging ECS service."
  type        = number
  default     = 85
}

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate before triggering staging alarm."
  type        = number
  default     = 2
}

variable "alarm_period_seconds" {
  description = "CloudWatch alarm period in seconds for staging."
  type        = number
  default     = 60
}

variable "alarm_actions" {
  description = "List of alarm action ARNs for staging alarms (for example SNS)."
  type        = list(string)
  default     = []
}
