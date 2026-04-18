variable "name" {
  description = "Prefix/name for ALB resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ALB target group is created."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for internet-facing ALB."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID attached to ALB."
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener."
  type        = string
}

variable "target_port" {
  description = "Backend target port exposed by ECS tasks."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Health check path for the ALB target group."
  type        = string
  default     = "/health"
}

variable "tags" {
  description = "Standard tags applied to ALB resources."
  type        = map(string)
  default     = {}
}
