import json
import boto3
import logging
import os
import time

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Failover Lambda function to:
    1. Promote RDS read replica to primary
    2. Update ECS task definition with new DB endpoint
    3. Scale up ECS service
    """
    
    secondary_region = os.environ['SECONDARY_REGION']
    
    # Initialize clients
    rds_client = boto3.client('rds', region_name=secondary_region)
    ecs_client = boto3.client('ecs', region_name=secondary_region)
    
    try:
        # Step 1: Check if read replica needs promotion or is already promoted
        secondary_db_id = os.environ['SECONDARY_DB_IDENTIFIER']
        
        # Get current DB state
        db_response = rds_client.describe_db_instances(
            DBInstanceIdentifier=secondary_db_id
        )
        db_instance = db_response['DBInstances'][0]
        new_endpoint = db_instance['Endpoint']['Address']
        
        # Check if it's still a read replica
        if 'ReadReplicaSourceDBInstanceIdentifier' in db_instance and db_instance['ReadReplicaSourceDBInstanceIdentifier']:
            logger.info(f"Promoting read replica: {secondary_db_id}")
            
            rds_client.promote_read_replica(
                DBInstanceIdentifier=secondary_db_id
            )
            
            # Wait for promotion to complete
            logger.info("Waiting for RDS promotion to complete...")
            waiter = rds_client.get_waiter('db_instance_available')
            waiter.wait(
                DBInstanceIdentifier=secondary_db_id,
                WaiterConfig={
                    'Delay': 30,
                    'MaxAttempts': 40  # Wait up to 20 minutes
                }
            )
            
            # Get updated endpoint after promotion
            db_response = rds_client.describe_db_instances(
                DBInstanceIdentifier=secondary_db_id
            )
            new_endpoint = db_response['DBInstances'][0]['Endpoint']['Address']
            logger.info(f"New DB endpoint after promotion: {new_endpoint}")
        else:
            logger.info(f"Database {secondary_db_id} is already promoted. Using endpoint: {new_endpoint}")
        
        # Step 2: Update ECS task definition with new DB endpoint
        cluster_arn = os.environ['SECONDARY_CLUSTER_ARN']
        service_arn = os.environ['SECONDARY_SERVICE_ARN']
        
        # Get current task definition
        service_response = ecs_client.describe_services(
            cluster=cluster_arn,
            services=[service_arn]
        )
        
        current_task_def_arn = service_response['services'][0]['taskDefinition']
        
        task_def_response = ecs_client.describe_task_definition(
            taskDefinition=current_task_def_arn
        )
        
        task_definition = task_def_response['taskDefinition']
        
        # Update environment variables
        for container in task_definition['containerDefinitions']:
            for env_var in container['environment']:
                if env_var['name'] == 'DB_HOST':
                    env_var['value'] = f"{new_endpoint}:3306"
                    logger.info(f"Updated DB_HOST to: {new_endpoint}:3306")
                elif env_var['name'] == 'USE_S3':
                    env_var['value'] = 'false'
                    logger.info("Set USE_S3 to false for DR environment")
        
        # Register new task definition
        new_task_def = {
            'family': task_definition['family'],
            'networkMode': task_definition['networkMode'],
            'requiresCompatibilities': task_definition['requiresCompatibilities'],
            'cpu': task_definition['cpu'],
            'memory': task_definition['memory'],
            'executionRoleArn': task_definition['executionRoleArn'],
            'taskRoleArn': task_definition['taskRoleArn'],
            'containerDefinitions': task_definition['containerDefinitions']
        }
        
        new_task_response = ecs_client.register_task_definition(**new_task_def)
        new_task_def_arn = new_task_response['taskDefinition']['taskDefinitionArn']
        
        logger.info(f"Registered new task definition: {new_task_def_arn}")
        
        # Step 3: Update and scale up the ECS service
        logger.info(f"Updating and scaling up ECS service: {service_arn}")
        
        ecs_client.update_service(
            cluster=cluster_arn,
            service=service_arn,
            taskDefinition=new_task_def_arn,
            desiredCount=1  # Scale to 1 instances for DR
        )
        
        logger.info("Failover completed successfully")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Failover completed successfully',
                'db_endpoint': new_endpoint,
                'service': service_arn,
                'task_definition': new_task_def_arn,
                'desiredCount': 2,
                'db_already_promoted': 'ReadReplicaSourceDBInstanceIdentifier' not in db_instance or not db_instance['ReadReplicaSourceDBInstanceIdentifier']
            })
        }
        
    except Exception as e:
        logger.error(f"Failover failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }