# Basic Example

This example demonstrates the basic usage of the terraform-aws-ecs-fargate-datadog-container-definitions module.

## Overview

This example shows how to:
- Use the module to get Datadog container definitions
- Use module outputs to automatically integrate Datadog into application containers
- Create an ECS task definition with the combined container definitions

## Prerequisites

Before using this example, you must have:

1. **ECS Task Execution Role** with the following permissions:
   - AWS managed policy: `AmazonECSTaskExecutionRolePolicy`
   - Permission to access the Datadog API key secret (use module's `task_execution_role_policy_json` output)

2. **ECS Task Role** with permissions for Datadog agent (use module's `task_role_policy_json` output)

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
- **Automatic Datadog integration using module outputs:**
  - `container_environment_variables` - APM and DogStatsD configuration
  - `container_mount_points` - Required volume mounts
  - `container_depends_on` - Container dependencies
  - `container_docker_labels` - Unified Service Tagging labels
  - `task_definition_volumes` - Required ECS task volumes
- Creating an ECS task definition with the combined container definitions
- No manual configuration needed - module outputs handle all Datadog integration

## Outputs

- `task_definition_arn` - The ARN of the created task definition
- `datadog_containers` - The Datadog container definitions (for reference)
