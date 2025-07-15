# Lambda function for failover
resource "aws_lambda_function" "failover" {
  filename         = "failover.zip"
  function_name    = "lampstack-failover"
  role            = aws_iam_role.lambda.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 900  # 15 minutes for RDS promotion

  environment {
    variables = {
      SECONDARY_CLUSTER_ARN   = var.secondary_cluster_arn
      SECONDARY_SERVICE_ARN   = var.secondary_service_arn
      SECONDARY_REGION        = var.secondary_region
      PRIMARY_DB_IDENTIFIER   = var.primary_db_identifier
      SECONDARY_DB_IDENTIFIER = var.secondary_db_identifier
    }
  }

  depends_on = [data.archive_file.lambda_zip]

  tags = var.tags
}

# Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "failover.zip"
  source {
    content  = file("${path.module}/failover.py")
    filename = "index.py"
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda" {
  name = "lampstack-failover-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for Lambda
resource "aws_iam_role_policy" "lambda" {
  name = "lampstack-failover-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "rds:PromoteReadReplica",
          "rds:DescribeDBInstances",
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Event Rule to trigger on primary service failure
resource "aws_cloudwatch_event_rule" "primary_failure" {
  name        = "lampstack-primary-failure"
  description = "Trigger failover when primary service fails"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    detail = {
      clusterArn = [var.primary_cluster_arn]
      lastStatus = ["STOPPED"]
      stoppedReason = [{
        exists = true
      }]
    }
  })

  tags = var.tags
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.primary_failure.name
  target_id = "TriggerFailoverLambda"
  arn       = aws_lambda_function.failover.arn
}

# Lambda permission for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.failover.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.primary_failure.arn
}