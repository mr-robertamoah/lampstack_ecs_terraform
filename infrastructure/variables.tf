variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary AWS region for pilot light"
  type        = string
  default     = "us-west-2"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "LAMP-Stack"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "default"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for the application (leave empty to skip Route 53)"
  type        = string
  default     = ""
}

variable "enable_manual_failover" {
  description = "Enable manual failover DNS record (dr.domain.com)"
  type        = bool
  default     = true
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}