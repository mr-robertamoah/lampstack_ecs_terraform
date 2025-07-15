# LAMP Stack ECS with Multi-Region Disaster Recovery

A production-ready LAMP stack application deployed on AWS ECS with automated disaster recovery across multiple regions using Terraform.

## Architecture Overview

This project implements a **pilot light disaster recovery** pattern with:
- **Primary Region**: Full production environment (ECS, RDS, ALB)
- **Secondary Region**: Minimal standby environment with RDS read replica
- **Automated Failover**: Lambda function triggered by CloudWatch events or manual invocation

## Project Structure

```
├── application/          # PHP LAMP stack blog application
│   ├── public/          # Web files (index.php, login.php, etc.)
│   ├── config/          # Database configuration
│   ├── Dockerfile       # Container definition
│   └── composer.json    # PHP dependencies
├── infrastructure/      # Terraform infrastructure code
│   ├── modules/         # Reusable Terraform modules
│   │   ├── lampstack/   # ECS, RDS, ALB resources
│   │   └── failover/    # Lambda disaster recovery function
│   ├── main.tf         # Main infrastructure configuration
│   └── *.tf            # Other Terraform files
├── build-and-deploy.sh # Docker build and ECR deployment script
└── dr-test.sh          # Disaster recovery testing script
```

## Application Features

The LAMP stack application is a simple blog system with:
- User registration and authentication
- Post creation and viewing
- MySQL database backend
- Responsive web interface
- Session management

## Infrastructure Components

### Primary Region (Production)
- **ECS Cluster**: Runs containerized PHP application
- **RDS MySQL**: Primary database with automated backups
- **Application Load Balancer**: Routes traffic to ECS tasks
- **ECR Repository**: Stores Docker images
- **VPC**: Isolated network with public/private subnets

### Secondary Region (Pilot Light)
- **ECS Cluster**: Standby cluster (0 running tasks initially)
- **RDS Read Replica**: Synchronized with primary database
- **Application Load Balancer**: Ready for failover traffic
- **ECR Repository**: Mirror of primary region images

### Disaster Recovery
- **Lambda Function**: Automates failover process
- **CloudWatch Events**: Monitors primary region health
- **Route 53**: DNS failover (optional)

## Prerequisites

- AWS CLI configured with appropriate permissions
- Docker installed
- Terraform >= 1.0
- jq (for JSON processing in scripts)

## Quick Start

### 1. Clone and Configure

```bash
git clone <repository-url>
cd lampstack_ecs_terraform
```

### 2. Set Environment Variables

```bash
export AWS_PROFILE=your-profile
export PRIMARY_REGION=us-east-1
export SECONDARY_REGION=us-west-2
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

### 3. Configure Terraform

```bash
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
primary_region   = "us-east-1"
secondary_region = "us-west-2"
db_password      = "your-secure-password"
aws_profile      = "your-profile"
account_id       = "123456789012"

# Optional: Configure custom domain
# domain_name = "lampstack.example.com"
```

### 4. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 5. Build and Deploy Application

```bash
cd ..
chmod +x build-and-deploy.sh
./build-and-deploy.sh
```

### 6. Update ECS Services

```bash
UPDATE_SERVICE=true ./build-and-deploy.sh
```

## Detailed Deployment Steps

### Infrastructure Deployment

1. **Initialize Terraform**:
   ```bash
   cd infrastructure
   terraform init
   ```

2. **Review planned changes**:
   ```bash
   terraform plan
   ```

3. **Deploy infrastructure**:
   ```bash
   terraform apply
   ```

4. **Get outputs**:
   ```bash
   terraform output
   ```

### Application Deployment

The `build-and-deploy.sh` script automates:

1. **Docker image building**:
   ```bash
   cd application
   docker build -t lampstack:latest .
   ```

2. **ECR authentication** for both regions

3. **Image tagging and pushing** to both ECR repositories

4. **ECS service updates** (if `UPDATE_SERVICE=true`)

#### Manual ECR Deployment

```bash
# Build image
cd application
docker build -t lampstack:latest .

# Login to ECR (Primary)
aws ecr get-login-password --region $PRIMARY_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$PRIMARY_REGION.amazonaws.com

# Tag and push
docker tag lampstack:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.$PRIMARY_REGION.amazonaws.com/lampstack:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$PRIMARY_REGION.amazonaws.com/lampstack:latest

# Repeat for secondary region...
```

## Disaster Recovery Testing

### Automated DR Testing

Use the provided script to test the complete DR process:

```bash
chmod +x dr-test.sh
./dr-test.sh
```

This script:
1. Checks initial ECS service status
2. Triggers the failover Lambda function
3. Monitors service scaling and health
4. Verifies ALB target health
5. Provides secondary region endpoint

### Manual DR Testing

#### 1. Check Current Status

```bash
# Primary region ECS status
aws ecs describe-services \
  --cluster production-cluster \
  --services production-service \
  --region $PRIMARY_REGION

# Secondary region ECS status
aws ecs describe-services \
  --cluster pilot-light-cluster \
  --services pilot-light-service \
  --region $SECONDARY_REGION
```

#### 2. Trigger Manual Failover

```bash
# Invoke failover Lambda
aws lambda invoke \
  --function-name lampstack-failover \
  --region $PRIMARY_REGION \
  response.json

# Check response
cat response.json | jq '.'
```

#### 3. Monitor Failover Progress

```bash
# Watch ECS service scaling
watch "aws ecs describe-services \
  --cluster pilot-light-cluster \
  --services pilot-light-service \
  --region $SECONDARY_REGION \
  --query 'services[0].{Desired:desiredCount,Running:runningCount,Pending:pendingCount}'"
```

#### 4. Verify Application Access

```bash
# Get secondary ALB endpoint
terraform -chdir=infrastructure output secondary_alb_dns

# Test application
curl -I http://$(terraform -chdir=infrastructure output -raw secondary_alb_dns)
```

### CloudWatch Automatic Failover

The system automatically triggers failover when:
- ECS tasks in primary region stop unexpectedly
- CloudWatch detects service failures
- Custom health check failures (if configured)

Monitor CloudWatch Events:
```bash
aws events describe-rule \
  --name lampstack-primary-failure \
  --region $PRIMARY_REGION
```

## Monitoring and Maintenance

### Key Metrics to Monitor

1. **ECS Service Health**:
   - Running task count
   - Service CPU/Memory utilization
   - Task start/stop events

2. **RDS Performance**:
   - Database connections
   - Read replica lag
   - Query performance

3. **Load Balancer**:
   - Target health status
   - Request count and latency
   - Error rates

### Regular Maintenance Tasks

1. **Test DR procedures monthly**:
   ```bash
   ./dr-test.sh
   ```

2. **Update application images**:
   ```bash
   UPDATE_SERVICE=true ./build-and-deploy.sh
   ```

3. **Review CloudWatch logs**:
   ```bash
   aws logs describe-log-groups --region $PRIMARY_REGION
   ```

4. **Backup verification**:
   ```bash
   aws rds describe-db-snapshots \
     --db-instance-identifier production-lampstack-db
   ```

## Troubleshooting

### Common Issues

1. **ECS Tasks Not Starting**:
   - Check ECR image availability
   - Verify task definition environment variables
   - Review CloudWatch logs

2. **Database Connection Failures**:
   - Verify security group rules
   - Check RDS endpoint configuration
   - Validate credentials

3. **Failover Not Working**:
   - Check Lambda function logs
   - Verify IAM permissions
   - Test RDS read replica status

### Useful Commands

```bash
# Check ECS task logs
aws logs get-log-events \
  --log-group-name /ecs/lampstack-task \
  --log-stream-name ecs/lampstack/task-id

# Verify RDS read replica
aws rds describe-db-instances \
  --db-instance-identifier pilot-light-lampstack-db

# Test Lambda function
aws lambda invoke \
  --function-name lampstack-failover \
  --log-type Tail \
  response.json
```

## Cost Optimization

- **Pilot Light**: Secondary region runs minimal resources (0 ECS tasks)
- **RDS Read Replica**: Only pay for storage and minimal compute
- **Lambda**: Pay per execution for DR testing
- **ECR**: Minimal storage costs for container images

## Security Considerations

- Database passwords stored in Terraform variables (use AWS Secrets Manager for production)
- VPC with private subnets for database access
- Security groups restrict access to necessary ports
- IAM roles follow least privilege principle

## Cleanup

To destroy all resources:

```bash
cd infrastructure
terraform destroy
```

**Warning**: This will permanently delete all data including databases.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test thoroughly
4. Submit a pull request

## License

This project is licensed under the MIT License.