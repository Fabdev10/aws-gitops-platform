output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ECS cluster ARN."
  value       = aws_ecs_cluster.this.arn
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "service_arn" {
  description = "ECS service ARN."
  value       = aws_ecs_service.this.id
}

output "task_definition_arn" {
  description = "Latest ECS task definition ARN."
  value       = aws_ecs_task_definition.this.arn
}

output "autoscaling_target_resource_id" {
  description = "App Auto Scaling resource ID for ECS service desired count."
  value       = try(aws_appautoscaling_target.ecs_service[0].resource_id, null)
}

output "cpu_scaling_policy_arn" {
  description = "ARN of ECS CPU target tracking scaling policy."
  value       = try(aws_appautoscaling_policy.cpu[0].arn, null)
}

output "memory_scaling_policy_arn" {
  description = "ARN of ECS memory target tracking scaling policy."
  value       = try(aws_appautoscaling_policy.memory[0].arn, null)
}

output "cpu_alarm_name" {
  description = "CloudWatch alarm name for high ECS CPU utilization."
  value       = try(aws_cloudwatch_metric_alarm.ecs_high_cpu[0].alarm_name, null)
}

output "memory_alarm_name" {
  description = "CloudWatch alarm name for high ECS memory utilization."
  value       = try(aws_cloudwatch_metric_alarm.ecs_high_memory[0].alarm_name, null)
}
