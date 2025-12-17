# Basic Example

This example demonstrates the basic usage of the terraform-aws-ecs-fargate-datadog-container-definitions module.

## Overview

This example shows how to:
- Use the module to get Datadog container definitions
- Combine Datadog containers with your application containers
- Create an ECS task definition with the combined container definitions

## Prerequisites

Before using this example, you must have:

1. **ECS Task Execution Role** with the following permissions:
   - AWS managed policy: `AmazonECSTaskExecutionRolePolicy`
   - Permission to access the Datadog API key secret:
     ```json
     {
       "Effect": "Allow",
       "Action": ["secretsmanager:GetSecretValue"],
       "Resource": ["arn:aws:secretsmanager:REGION:ACCOUNT:secret:datadog-api-key-*"]
     }
     ```

2. **ECS Task Role** with permissions for Datadog agent:
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "ecs:ListClusters",
       "ecs:ListContainerInstances",
       "ecs:DescribeContainerInstances"
     ],
     "Resource": ["*"]
   }
   ```

3. **Datadog API Key Secret** in AWS Secrets Manager:
   ```bash
   aws secretsmanager create-secret \
     --name datadog-api-key \
     --secret-string "your-datadog-api-key"
   ```

## Usage

1. Create a `terraform.tfvars` file with your configuration:
   ```hcl
   datadog_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog-api-key-abc123"
   execution_role_arn         = "arn:aws:iam::123456789012:role/ecsTaskExecutionRole"
   task_role_arn              = "arn:aws:iam::123456789012:role/ecsTaskRole"
   service_name               = "my-service"
   environment                = "dev"
   app_image                  = "my-app:latest"
   ```

2. Run Terraform:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## What This Example Demonstrates

- Using the module to generate Datadog container definitions
- Combining Datadog containers with application containers using `concat()`
- Creating an ECS task definition with the combined container definitions
- Configuring Unified Service Tagging (UST) for Datadog
- Proper volume mounts and container dependencies for Datadog integration

## Outputs

- `task_definition_arn` - The ARN of the created task definition
- `datadog_containers` - The Datadog container definitions (for reference)
