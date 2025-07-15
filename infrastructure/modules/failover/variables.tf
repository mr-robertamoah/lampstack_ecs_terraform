variable "primary_cluster_arn" {
  description = "Primary ECS cluster ARN"
  type        = string
}

variable "secondary_cluster_arn" {
  description = "Secondary ECS cluster ARN"
  type        = string
}

variable "secondary_service_arn" {
  description = "Secondary ECS service ARN"
  type        = string
}

variable "secondary_region" {
  description = "Secondary AWS region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "primary_db_identifier" {
  description = "Primary RDS instance identifier"
  type        = string
}

variable "secondary_db_identifier" {
  description = "Secondary RDS instance identifier"
  type        = string
}