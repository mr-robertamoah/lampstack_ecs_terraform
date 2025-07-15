#!/bin/bash

# DR Test Script - Check status, trigger failover, verify results

set -e

# Configuration
AWS_PROFILE=${AWS_PROFILE:-sandbox}
SECONDARY_REGION=${SECONDARY_REGION:-eu-west-1}
PRIMARY_REGION=${PRIMARY_REGION:-eu-central-1}
CLUSTER_NAME="pilot-light-cluster"
SERVICE_NAME="pilot-light-service"
LAMBDA_FUNCTION="lampstack-failover"

echo "=== DR Test Script ==="
echo "Profile: $AWS_PROFILE"
echo "Secondary Region: $SECONDARY_REGION"
echo "Primary Region: $PRIMARY_REGION"
echo

# Function to check ECS service status
check_ecs_status() {
    echo "--- ECS Service Status ---"
    aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --region $SECONDARY_REGION \
        --profile $AWS_PROFILE \
        --query 'services[0].{DesiredCount:desiredCount,RunningCount:runningCount,PendingCount:pendingCount,Status:status}' \
        --output table
    echo
}

# Function to invoke Lambda
invoke_lambda() {
    echo "--- Invoking DR Lambda ---"
    aws lambda invoke \
        --function-name $LAMBDA_FUNCTION \
        --region $PRIMARY_REGION \
        --profile $AWS_PROFILE \
        dr-response.json > /dev/null
    
    echo "Lambda Response:"
    cat dr-response.json | jq '.'
    echo
}

# Function to wait for tasks to start
wait_for_tasks() {
    echo "--- Waiting for tasks to start (max 5 minutes) ---"
    local count=0
    while [ $count -lt 30 ]; do
        local running=$(aws ecs describe-services \
            --cluster $CLUSTER_NAME \
            --services $SERVICE_NAME \
            --region $SECONDARY_REGION \
            --profile $AWS_PROFILE \
            --query 'services[0].runningCount' \
            --output text)
        
        echo "Running tasks: $running"
        
        if [ "$running" -gt 0 ]; then
            echo "✅ Tasks are running!"
            break
        fi
        
        sleep 10
        count=$((count + 1))
    done
    echo
}

# Main execution
echo "1. Initial ECS Status:"
check_ecs_status

echo "2. Triggering DR Failover:"
invoke_lambda

echo "3. ECS Status After Failover:"
check_ecs_status

echo "4. Waiting for tasks to become healthy:"
wait_for_tasks

echo "5. Final ECS Status:"
check_ecs_status

# Check ALB health
echo "6. ALB Target Health:"
aws elbv2 describe-target-health \
    --target-group-arn $(aws elbv2 describe-target-groups \
        --names pilot-light-tg \
        --region $SECONDARY_REGION \
        --profile $AWS_PROFILE \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text) \
    --region $SECONDARY_REGION \
    --profile $AWS_PROFILE \
    --query 'TargetHealthDescriptions[].{Target:Target.Id,Health:TargetHealth.State}' \
    --output table 2>/dev/null || echo "No targets registered yet"

echo
echo "=== DR Test Complete ==="
echo "Check the secondary ALB endpoint:"
terraform -chdir=infrastructure output secondary_alb_dns

# Cleanup response file
rm -f dr-response.json