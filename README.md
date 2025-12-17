# terraform-aws-ecs-fargate-datadog-container-definitions

Terraform module for generating ECS Fargate container definitions with Datadog monitoring integration.

## Overview

This module provides container definitions for ECS Fargate tasks with Datadog Agent, log collection, and Cloud Workload Security (CWS) support. Based on DataDog's official [terraform-aws-ecs-datadog](https://github.com/DataDog/terraform-aws-ecs-datadog) module v1.0.6.

**Key Difference**: Unlike the full DataDog module which creates a complete ECS task definition resource, this module **only outputs the container definitions JSON**. This allows you to use these container definitions in your own task definition resources while maintaining full control over task-level settings.

## Features

- 🔍 **Datadog Agent**: Automatic setup with configurable resources and health checks
- 📊 **APM & DogStatsD**: Unix domain socket or UDP port configuration
- 📝 **Log Collection**: Optional Fluent Bit integration for log forwarding
- 🔐 **CWS**: Cloud Workload Security instrumentation
- 🏷️ **UST**: Unified Service Tagging support
- 🔄 **Container Enhancement**: Automatically adds Datadog-specific environment variables, mounts, and dependencies to your containers

## Usage

### Basic Example

```hcl
module "datadog_container_definitions" {
  source = "github.com/Luscii/terraform-aws-ecs-fargate-datadog-container-definitions"

  # Your application containers
  container_definitions = jsonencode([
    {
      name      = "my-app"
      image     = "my-app:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
    }
  ])

  # Datadog configuration
  dd_api_key_secret = {
    arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog-api-key"
  }
  dd_site = "datadoghq.com"

  # Unified Service Tagging
  dd_service = "my-service"
  dd_env     = "production"
  dd_version = "1.0.0"
}

# Use the container definitions in your task definition
resource "aws_ecs_task_definition" "this" {
  family                   = "my-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = module.datadog_container_definitions.container_definitions
}
```

### Example with Log Collection

```hcl
module "datadog_container_definitions" {
  source = "github.com/Luscii/terraform-aws-ecs-fargate-datadog-container-definitions"

  container_definitions = jsonencode([
    {
      name      = "my-app"
      image     = "my-app:latest"
      cpu       = 256
      memory    = 512
      essential = true
    }
  ])

  dd_api_key_secret = {
    arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog-api-key"
  }

  # Enable log collection
  dd_log_collection = {
    enabled = true
    fluentbit_config = {
      is_log_router_essential = false
      log_driver_configuration = {
        host_endpoint = "http-intake.logs.datadoghq.com"
        service_name  = "my-service"
        source_name   = "my-app"
      }
    }
  }

  dd_service = "my-service"
  dd_env     = "production"
}
```

### Example with Cloud Workload Security (CWS)

```hcl
module "datadog_container_definitions" {
  source = "github.com/Luscii/terraform-aws-ecs-fargate-datadog-container-definitions"

  container_definitions = jsonencode([
    {
      name       = "my-app"
      image      = "my-app:latest"
      cpu        = 256
      memory     = 512
      essential  = true
      entryPoint = ["/usr/local/bin/docker-entrypoint.sh"]
    }
  ])

  dd_api_key_secret = {
    arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog-api-key"
  }

  # Enable CWS
  dd_cws = {
    enabled          = true
    cpu              = 128
    memory_limit_mib = 256
  }

  # Required for CWS stability
  dd_is_datadog_dependency_enabled = true
}
```

## Important Notes

### API Key Configuration

You must provide **either** `dd_api_key` (plaintext) **or** `dd_api_key_secret` (AWS Secrets Manager), but not both:

```hcl
# Option 1: Use Secrets Manager (recommended)
dd_api_key_secret = {
  arn = "arn:aws:secretsmanager:region:account:secret:name"
}

# Option 2: Use plaintext (not recommended for production)
dd_api_key = "your-datadog-api-key"
```

### IAM Permissions Required

Since this module doesn't create IAM resources, you must ensure your task execution and task roles have the necessary permissions:

**Task Execution Role** (if using `dd_api_key_secret`):
```hcl
data "aws_iam_policy_document" "execution_role_policy" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.dd_api_key_secret.arn]
  }
}
```

**Task Role** (for Datadog Agent):
```hcl
data "aws_iam_policy_document" "task_role_policy" {
  statement {
    actions = [
      "ecs:ListClusters",
      "ecs:ListContainerInstances",
      "ecs:DescribeContainerInstances"
    ]
    resources = ["*"]
  }
}
```

### Platform Compatibility

- **Log Collection**: Only supported on Linux containers
- **Read-only Root Filesystem**: Only supported on Linux containers
- **CWS**: Only supported on Linux containers

## What Gets Added to Your Containers

The module automatically enhances your application containers with:

1. **Environment Variables**:
   - `DD_TRACE_AGENT_URL` - APM socket URL (if socket-based APM is enabled)
   - `DD_DOGSTATSD_URL` - DogStatsD socket URL (if socket-based DSD is enabled)
   - `DD_AGENT_HOST` - Agent host for UDP mode
   - `DD_ENV`, `DD_SERVICE`, `DD_VERSION` - Unified Service Tags
   - `DD_PROFILING_ENABLED` - If profiling is enabled

2. **Volume Mounts**:
   - `/var/run/datadog` - For APM and DogStatsD sockets
   - `/cws-instrumentation-volume` - For CWS (if enabled)

3. **Container Dependencies**:
   - Waits for Datadog agent health check
   - Waits for log router health check (if enabled)
   - Waits for CWS initialization (if enabled)

4. **Docker Labels**: UST labels for environment, service, and version

## Configuration

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

## Source Attribution

This module is derived from DataDog's official Terraform module:
- **Repository**: https://github.com/DataDog/terraform-aws-ecs-datadog
- **Version**: v1.0.6
- **Module**: `modules/ecs_fargate`
- **License**: Apache License Version 2.0

See `.github/instructions/module-overview.instructions.md` for detailed information about updating this module.

## License

Apache License Version 2.0. See LICENSE file for details.
