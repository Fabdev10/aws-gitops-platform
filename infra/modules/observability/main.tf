resource "aws_cloudwatch_dashboard" "service" {
  count = var.enabled ? 1 : 0

  dashboard_name = "${var.name}-ops"

  dashboard_body = jsonencode({
    widgets = [
      {
        "type" : "text",
        "x" : 0,
        "y" : 0,
        "width" : 24,
        "height" : 2,
        "properties" : {
          "markdown" : "# ${var.name} operational dashboard\\nEnvironment dashboard for ECS service `${var.ecs_service_name}` behind ALB `${var.alb_name}`."
        }
      },
      {
        "type" : "metric",
        "x" : 0,
        "y" : 2,
        "width" : 12,
        "height" : 6,
        "properties" : {
          "region" : var.region,
          "title" : "ECS CPU and Memory Utilization",
          "view" : "timeSeries",
          "stat" : "Average",
          "period" : 60,
          "metrics" : [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]
          ]
        }
      },
      {
        "type" : "metric",
        "x" : 12,
        "y" : 2,
        "width" : 12,
        "height" : 6,
        "properties" : {
          "region" : var.region,
          "title" : "ECS Running and Pending Tasks",
          "view" : "timeSeries",
          "stat" : "Average",
          "period" : 60,
          "metrics" : [
            ["AWS/ECS", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name],
            ["AWS/ECS", "PendingTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]
          ]
        }
      },
      {
        "type" : "metric",
        "x" : 0,
        "y" : 8,
        "width" : 12,
        "height" : 6,
        "properties" : {
          "region" : var.region,
          "title" : "ALB Request Volume and 5XX Errors",
          "view" : "timeSeries",
          "stat" : "Sum",
          "period" : 60,
          "metrics" : [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix]
          ]
        }
      },
      {
        "type" : "metric",
        "x" : 12,
        "y" : 8,
        "width" : 12,
        "height" : 6,
        "properties" : {
          "region" : var.region,
          "title" : "ALB Latency and Target Health",
          "view" : "timeSeries",
          "stat" : "Average",
          "period" : 60,
          "metrics" : [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix]
          ]
        }
      }
    ]
  })
}
