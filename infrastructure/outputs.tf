output "primary_alb_dns" {
  description = "Primary region ALB DNS name"
  value       = module.primary_lampstack.alb_dns_name
}

output "secondary_alb_dns" {
  description = "Secondary region ALB DNS name"
  value       = module.secondary_lampstack.alb_dns_name
}

output "primary_db_endpoint" {
  description = "Primary database endpoint"
  value       = module.primary_lampstack.db_endpoint
  sensitive   = true
}

output "secondary_db_endpoint" {
  description = "Secondary database endpoint"
  value       = module.secondary_lampstack.db_endpoint
  sensitive   = true
}

output "route53_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].zone_id : null
}

output "route53_name_servers" {
  description = "Route 53 name servers"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].name_servers : null
}

output "domain_name" {
  description = "Primary domain name"
  value       = var.domain_name != "" ? var.domain_name : null
}

output "dr_domain_name" {
  description = "DR domain name for manual failover"
  value       = var.domain_name != "" && var.enable_manual_failover ? "dr.${var.domain_name}" : null
}

output "primary_ecr_repository_url" {
  description = "Primary ECR repository URL"
  value       = aws_ecr_repository.lampstack_primary.repository_url
}

output "secondary_ecr_repository_url" {
  description = "Secondary ECR repository URL"
  value       = aws_ecr_repository.lampstack_secondary.repository_url
}