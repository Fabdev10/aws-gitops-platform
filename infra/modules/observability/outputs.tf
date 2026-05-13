output "dashboard_name" {
  description = "CloudWatch dashboard name for this environment."
  value       = try(aws_cloudwatch_dashboard.service[0].dashboard_name, null)
}
