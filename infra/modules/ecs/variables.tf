variable "name" {
  description = "Prefix/name for ECS resources."
  type        = string
}

variable "region" {
  description = "AWS region for logging configuration."
  type        = string
}

variable "image_uri" {
  description = "Full ECR image URI including tag."
  type        = string
}

variable "container_name" {
  description = "Container name used by ECS task and ALB binding."
  type        = string
  default     = "app"
}

variable "container_port" {
  description = "Container port exposed by FastAPI app."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Path used for ECS container health checks."
  type        = string
  default     = "/health"
}

variable "task_cpu" {
  description = "Task CPU units for Fargate."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Task memory in MiB for Fargate."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of ECS tasks to keep running."
  type        = number
  default     = 2
}

variable "enable_autoscaling" {
  description = "Enable ECS service target tracking autoscaling."
  type        = bool
  default     = true
}

variable "autoscaling_min_capacity" {
  description = "Minimum number of ECS tasks when autoscaling is enabled."
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of ECS tasks when autoscaling is enabled."
  type        = number
  default     = 4
}

variable "autoscaling_cpu_target" {
  description = "Target average ECS CPU utilization percentage for scaling."
  type        = number
  default     = 60
}

variable "autoscaling_memory_target" {
  description = "Target average ECS memory utilization percentage for scaling."
  type        = number
  default     = 75
}

variable "private_subnet_ids" {
  description = "Private subnet IDs where ECS tasks run."
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group attached to ECS tasks."
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN receiving ECS traffic."
  type        = string
}

variable "secrets" {
  description = "Map of ENV_VAR_NAME => Secrets Manager secret ARN."
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 30
}

variable "enable_service_alarms" {
  description = "Enable CloudWatch alarms for ECS service CPU and memory."
  type        = bool
  default     = true
}

variable "alarm_cpu_utilization_threshold" {
  description = "CPU utilization percentage threshold for alarm."
  type        = number
  default     = 80
}

variable "alarm_memory_utilization_threshold" {
  description = "Memory utilization percentage threshold for alarm."
  type        = number
  default     = 85
}

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate before triggering alarm."
  type        = number
  default     = 2
}

variable "alarm_period_seconds" {
  description = "Length of each CloudWatch alarm evaluation period in seconds."
  type        = number
  default     = 60
}

variable "alarm_actions" {
  description = "SNS topic ARNs or other alarm actions to invoke when alarm is in ALARM state."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Standard tags applied to ECS resources."
  type        = map(string)
  default     = {}
}
