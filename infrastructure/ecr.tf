# ECR Repository for the application (Primary Region)
resource "aws_ecr_repository" "lampstack_primary" {
  provider = aws.primary
  
  name                 = "lampstack"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

# ECR Repository for the application (Secondary Region)
resource "aws_ecr_repository" "lampstack_secondary" {
  provider = aws.secondary
  
  name                 = "lampstack"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

# ECR Replication Configuration
resource "aws_ecr_replication_configuration" "lampstack" {
  provider = aws.primary
  
  replication_configuration {
    rule {
      destination {
        region      = var.secondary_region
        registry_id = var.account_id
      }
      
      repository_filter {
        filter      = "lampstack"
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

resource "aws_ecr_lifecycle_policy" "lampstack_primary" {
  provider   = aws.primary
  repository = aws_ecr_repository.lampstack_primary.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "lampstack_secondary" {
  provider   = aws.secondary
  repository = aws_ecr_repository.lampstack_secondary.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}