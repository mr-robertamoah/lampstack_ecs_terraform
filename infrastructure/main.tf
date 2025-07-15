terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region  = var.primary_region
  profile = var.aws_profile
}

provider "aws" {
  region  = var.primary_region
  profile = var.aws_profile
  alias   = "primary"
}

provider "aws" {
  region  = var.secondary_region
  profile = var.aws_profile
  alias   = "secondary"
}

# Primary region deployment
module "primary_lampstack" {
  source = "./modules/lampstack"

  providers = {
    aws = aws.primary
  }

  account            = var.account_id
  environment        = "production"
  region            = var.primary_region
  vpc_cidr          = "10.0.0.0/16"
  desired_count     = 1
  ecr_repository_url = aws_ecr_repository.lampstack_primary.repository_url
  db_password       = var.db_password

  tags = var.tags
}

# Secondary region (pilot light)
module "secondary_lampstack" {
  source = "./modules/lampstack"

  providers = {
    aws = aws.secondary
  }

  environment           = "pilot-light"
  region                = var.secondary_region
  vpc_cidr              = "10.1.0.0/16"
  desired_count         = 0 # Pilot light - no running tasks initially
  ecr_repository_url    = aws_ecr_repository.lampstack_secondary.repository_url
  db_password           = var.db_password
  primary_db_identifier = module.primary_lampstack.db_identifier
  primary_region        = var.primary_region
  account               = var.account_id

  tags = var.tags
}

# Failover Lambda
module "failover_lambda" {
  source = "./modules/failover"

  providers = {
    aws = aws.primary
  }

  primary_cluster_arn     = module.primary_lampstack.cluster_arn
  secondary_cluster_arn   = module.secondary_lampstack.cluster_arn
  secondary_service_arn   = module.secondary_lampstack.service_arn
  secondary_region        = var.secondary_region
  primary_db_identifier   = module.primary_lampstack.db_identifier
  secondary_db_identifier = module.secondary_lampstack.db_identifier

  tags = var.tags
}