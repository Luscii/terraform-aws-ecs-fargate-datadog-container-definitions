# Basic Example

This example demonstrates the basic usage of the terraform-aws-ecs-fargate-datadog-container-definitions module.

## Overview

This example creates:
- ECS Task Definition using the container definitions from the module
- Required IAM roles for task execution and task runtime
- Proper permissions for accessing Datadog API key from Secrets Manager
- Datadog Agent permissions for ECS metadata

## Usage

1. Create a secret in AWS Secrets Manager containing your Datadog API key:
```bash
aws secretsmanager create-secret \
  --name datadog-api-key \
  --secret-string "your-datadog-api-key"
```

2. Update the `terraform.tfvars` file:
```hcl
datadog_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog-api-key-abc123"
service_name               = "my-service"
environment                = "dev"
app_image                  = "my-app:latest"
```

3. Run Terraform:
```bash
terraform init
terraform plan
terraform apply
```

## What This Example Demonstrates

- Using the module to generate container definitions
- Creating an ECS task definition with the generated container definitions
- Setting up required IAM roles and policies
- Configuring Unified Service Tagging (UST) for Datadog

## Outputs

- `task_definition_arn` - The ARN of the created task definition
- `container_definitions` - The JSON container definitions (for debugging)
- `execution_role_arn` - The ARN of the execution role
- `task_role_arn` - The ARN of the task role
