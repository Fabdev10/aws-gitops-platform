variable "name" {
  description = "Prefix/name used for dashboard resources."
  type        = string
}

variable "region" {
  description = "AWS region used in widget metrics."
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name displayed and used by widgets."
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name displayed and used by widgets."
  type        = string
}

variable "alb_name" {
  description = "ALB name used for labeling the dashboard."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix used by CloudWatch ApplicationELB metrics."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix used by ALB and ECS widgets."
  type        = string
}

variable "enabled" {
  description = "Enable or disable dashboard creation."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Standard tags applied to observability resources."
  type        = map(string)
  default     = {}
}
