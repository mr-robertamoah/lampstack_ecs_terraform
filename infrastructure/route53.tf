# Route 53 Hosted Zone
resource "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0

  name = var.domain_name
  tags = var.tags
}

# Primary region health check
resource "aws_route53_health_check" "primary" {
  count = var.domain_name != "" ? 1 : 0

  fqdn                            = module.primary_lampstack.alb_dns_name
  port                            = 80
  type                            = "HTTP"
  resource_path                   = "/"
  failure_threshold               = 3
  request_interval                = 30
  cloudwatch_alarm_region         = var.primary_region
  cloudwatch_alarm_name           = module.primary_lampstack.service_unhealthy_alarm_name
  insufficient_data_health_status = "Unhealthy"

  tags = merge(var.tags, {
    Name = "Primary ALB Health Check"
  })
}

# Primary region DNS record with failover
resource "aws_route53_record" "primary" {
  count = var.domain_name != "" ? 1 : 0

  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  set_identifier = "primary"
  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary[0].id

  alias {
    name                   = module.primary_lampstack.alb_dns_name
    zone_id                = module.primary_lampstack.alb_zone_id
    evaluate_target_health = true
  }
}

# Secondary region DNS record with failover
resource "aws_route53_record" "secondary" {
  count = var.domain_name != "" ? 1 : 0

  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  set_identifier = "secondary"
  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = module.secondary_lampstack.alb_dns_name
    zone_id                = module.secondary_lampstack.alb_zone_id
    evaluate_target_health = true
  }
}

# Manual failover record (for manual DNS cutover)
resource "aws_route53_record" "manual_failover" {
  count = var.domain_name != "" && var.enable_manual_failover ? 1 : 0

  zone_id = aws_route53_zone.main[0].zone_id
  name    = "dr.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.secondary_lampstack.alb_dns_name
    zone_id                = module.secondary_lampstack.alb_zone_id
    evaluate_target_health = true
  }
}