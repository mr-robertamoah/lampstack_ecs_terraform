variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "ecr_repository_url" {
  description = "ECR repository URL for the application image"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "primary_db_identifier" {
  description = "Primary database identifier (for DR region)"
  type        = string
  default     = ""
}

variable "primary_region" {
  description = "Primary AWS region (for cross-region replica)"
  type        = string
  default     = ""
}

variable "account" {
  description = "AWS account ID"
  type        = string
}