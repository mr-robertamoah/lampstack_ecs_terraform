#!/bin/bash

# Build and deploy script for LAMP stack application

set -e

# Variables
AWS_PROFILE=${AWS_PROFILE:-sandbox}
PRIMARY_REGION=${PRIMARY_REGION:-eu-central-1}
SECONDARY_REGION=${SECONDARY_REGION:-eu-west-1}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text)
ECR_REPO_NAME="lampstack"
IMAGE_TAG=${IMAGE_TAG:-latest}

echo "Building and deploying LAMP stack application..."

# Build Docker image
echo "Building Docker image..."
cd application
docker build -t $ECR_REPO_NAME:$IMAGE_TAG .

# Login to ECR (Primary Region)
echo "Logging in to Primary ECR..."
aws ecr get-login-password --profile $AWS_PROFILE --region $PRIMARY_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$PRIMARY_REGION.amazonaws.com

# Login to ECR (Secondary Region)
echo "Logging in to Secondary ECR..."
aws ecr get-login-password --profile $AWS_PROFILE --region $SECONDARY_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$SECONDARY_REGION.amazonaws.com

# Tag and push image to Primary Region
echo "Tagging and pushing image to Primary Region..."
docker tag $ECR_REPO_NAME:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$PRIMARY_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG
docker push $AWS_ACCOUNT_ID.dkr.ecr.$PRIMARY_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG

# Tag and push image to Secondary Region
echo "Tagging and pushing image to Secondary Region..."
docker tag $ECR_REPO_NAME:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$SECONDARY_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG
docker push $AWS_ACCOUNT_ID.dkr.ecr.$SECONDARY_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG

echo "Images pushed successfully to both regions!"
echo "Primary Repository: $AWS_ACCOUNT_ID.dkr.ecr.$PRIMARY_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG"
echo "Secondary Repository: $AWS_ACCOUNT_ID.dkr.ecr.$SECONDARY_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG"

# Update ECS service (optional)
if [ "$UPDATE_SERVICE" = "true" ]; then
    echo "Updating ECS services..."
    aws ecs update-service --profile $AWS_PROFILE --cluster production-cluster --service production-service --force-new-deployment --region $PRIMARY_REGION
    echo "Primary ECS service update initiated"
    
    # Update secondary region service if desired_count > 0
    SECONDARY_REGION=${SECONDARY_REGION:-eu-west-1}
    aws ecs update-service --profile $AWS_PROFILE --cluster pilot-light-cluster --service pilot-light-service --force-new-deployment --region $SECONDARY_REGION 2>/dev/null || echo "Secondary service not running (pilot-light)"
fi