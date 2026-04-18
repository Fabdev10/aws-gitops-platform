output "alb_arn" {
  description = "ARN of the application load balancer."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB for Route53 aliases."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "Target group ARN used by ECS service."
  value       = aws_lb_target_group.this.arn
}
