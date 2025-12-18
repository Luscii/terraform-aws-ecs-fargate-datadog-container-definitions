# Terraform AWS ECS Fargate Datadog Container Definitions Module

## Overview

This module provides **only Datadog-related container definitions** for ECS Fargate tasks with Datadog monitoring integration. It is based on the [DataDog/terraform-aws-ecs-datadog](https://github.com/DataDog/terraform-aws-ecs-datadog) module version v1.0.6, specifically extracted from the `modules/ecs_fargate` component.

## Purpose

Unlike the full DataDog module which creates a complete ECS task definition resource, this module **only** provides the Datadog container definitions as outputs. This allows you to:

- Get just the Datadog containers (Agent, Log Router, CWS) from this module
- Combine them with your own application containers in your task definition
- Maintain full control over your ECS task configuration
- Manually configure Datadog integration in your application containers as needed

## Key Features

This module automatically configures:

- **Datadog Agent Container**: Main monitoring agent with configurable CPU, memory, and health checks
- **Log Router Container** (optional): AWS Firelens/Fluent Bit integration for log forwarding to Datadog
- **CWS Container** (optional): Cloud Workload Security instrumentation for runtime security monitoring

## Module Outputs

The module provides these outputs:

1. `datadog_agent_container` - List containing the Datadog Agent container definition
2. `datadog_log_router_container` - List containing the log router container (empty if disabled)
3. `datadog_cws_container` - List containing the CWS container (empty if disabled)
4. `datadog_containers` - Combined list of all Datadog containers (recommended)
5. `datadog_containers_json` - JSON-encoded string of all Datadog containers

## Usage Pattern

Users combine the Datadog containers with their application containers:

```hcl
module "datadog_containers" {
  source = "..."
  
  dd_api_key_secret = { arn = "..." }
  dd_service = "my-service"
  dd_env     = "production"
}

locals {
  app_containers = [
    # Your application containers with Datadog integration
  ]
}

resource "aws_ecs_task_definition" "this" {
  container_definitions = jsonencode(
    concat(
      module.datadog_containers.datadog_containers,
      local.app_containers
    )
  )
  # ... other config
}
```

## What Users Must Configure

Since this module doesn't modify application containers, users must manually add to their containers:

- **Environment Variables**: `DD_TRACE_AGENT_URL`, `DD_DOGSTATSD_URL`, `DD_ENV`, `DD_SERVICE`, `DD_VERSION`
- **Volume Mounts**: `/var/run/datadog` for sockets, `/cws-instrumentation-volume` for CWS
- **Dependencies**: Wait for `datadog-agent` and `cws-instrumentation-init` containers
- **Docker Labels**: UST labels for environment, service, and version
- **Task Definition Volumes**: `dd-sockets`, `cws-instrumentation-volume` (if using CWS)

## Important Notes

1. **No Application Container Input**: This module does NOT accept application containers as input
2. **No Automatic Enhancement**: This module does NOT automatically modify application containers
3. **No IAM Resources**: This module does NOT create IAM roles or policies
4. **No Task Definition**: This module does NOT create the task definition resource itself

## Updating This Module

This module is based on DataDog's official module. To update to a newer version:

1. Check the latest release at https://github.com/DataDog/terraform-aws-ecs-datadog/releases
2. Review the `modules/ecs_fargate/datadog.tf` file for container definition logic
3. Extract only the Datadog container definitions (dd_agent_container, dd_log_container, dd_cws_container)
4. DO NOT include the `modified_container_definitions` logic that processes user containers
5. Update the version number in `main.tf` (local.version)
6. Test thoroughly with representative examples

## Source Attribution

This module is derived from:
- Repository: https://github.com/DataDog/terraform-aws-ecs-datadog
- Version: v1.0.6
- Module: `modules/ecs_fargate`
- License: Apache License Version 2.0

## Example Usage

See the README.md for complete usage examples.
