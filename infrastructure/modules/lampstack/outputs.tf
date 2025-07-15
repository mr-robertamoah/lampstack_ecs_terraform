output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = var.environment == "production" ? (length(aws_db_instance.main) > 0 ? aws_db_instance.main[0].endpoint : null) : (length(aws_db_instance.replica) > 0 ? aws_db_instance.replica[0].endpoint : null)
}

output "db_identifier" {
  description = "RDS instance identifier"
  value       = var.environment == "production" ? (length(aws_db_instance.main) > 0 ? aws_db_instance.main[0].identifier : null) : (length(aws_db_instance.replica) > 0 ? aws_db_instance.replica[0].identifier : null)
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "service_arn" {
  description = "ECS service ARN"
  value       = aws_ecs_service.app.id
}



output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB zone ID"
  value       = aws_lb.main.zone_id
}

output "service_unhealthy_alarm_name" {
  description = "Service unhealthy alarm name"
  value       = aws_cloudwatch_metric_alarm.service_unhealthy.alarm_name
}