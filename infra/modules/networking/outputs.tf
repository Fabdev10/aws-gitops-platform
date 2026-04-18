output "vpc_id" {
  description = "VPC ID for downstream modules."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by ALB/NAT."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by ECS tasks."
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "alb_security_group_id" {
  description = "Security group ID attached to ALB."
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "Security group ID attached to ECS service."
  value       = aws_security_group.ecs_service.id
}
