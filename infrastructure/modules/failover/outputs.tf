output "lambda_arn" {
  description = "Failover Lambda function ARN"
  value       = aws_lambda_function.failover.arn
}

output "lambda_function_name" {
  description = "Failover Lambda function name"
  value       = aws_lambda_function.failover.function_name
}