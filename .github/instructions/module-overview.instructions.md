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

  api_key           = { arn = "..." }
  service_name      = "my-service"
  stage             = "production"
  service_version   = "1.0.0"
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

## Variable Naming Convention

This module uses a different naming convention than the upstream DataDog module because of the inverted architecture:

### Why No `dd_` Prefix?

In the **upstream DataDog module** (`DataDog/terraform-aws-ecs-datadog`):
- The module takes your application containers as input and adds Datadog containers to them
- The `dd_` prefix makes sense to distinguish Datadog-specific variables from application variables
- Variables like `dd_service`, `dd_env`, `dd_api_key` are prefixed to avoid collision with app vars

In **this module**:
- The module ONLY provides Datadog containers (no application containers)
- ALL variables are inherently Datadog-related, making the `dd_` prefix redundant
- Users combine this module's outputs with their own application containers
- The `dd_` prefix adds unnecessary verbosity without adding clarity

### Naming Rules

When adding or updating variables from the upstream module:

1. **Remove `dd_` prefix** for general configuration:
   - `dd_api_key` → `api_key`
   - `dd_site` → `site`
   - `dd_registry` → `registry`
   - `dd_image_version` → `image_version`

2. **Use `agent_` prefix** for agent-specific configuration:
   - `dd_cpu` → `agent_cpu`
   - `dd_memory_limit_mib` → `agent_memory_limit_mib`
   - `dd_environment` → `agent_environment`
   - `dd_health_check` → `agent_health_check`
   - `dd_tags` → `agent_tags`
   - `dd_cluster_name` → `agent_cluster_name`

3. **Use service name only** for service-specific configuration objects:
   - `dd_apm` → `apm`
   - `dd_dogstatsd` → `dogstatsd`
   - `dd_log_collection` → `log_collection`
   - `dd_cws` → `cws`

4. **Use descriptive names** for Unified Service Tagging (UST):
   - `dd_service` → `service_name` (clearer purpose)
   - `dd_env` → `stage` (follows CloudPosse convention)
   - `dd_version` → `service_version` (clearer purpose)

### Rationale

- **Clarity**: Names should describe what they configure, not just that they're "Datadog-related"
- **Organization**: Prefixes distinguish between agent, service, and general config
- **Consistency**: Follows Terraform and CloudPosse naming best practices
- **Usability**: Shorter, more intuitive variable names improve developer experience

## Updating This Module

This module is based on DataDog's official module. To update to a newer version:

1. Check the latest release at https://github.com/DataDog/terraform-aws-ecs-datadog/releases
2. Review the `modules/ecs_fargate/datadog.tf` file for container definition logic
3. Extract only the Datadog container definitions (agent_container, log_router_container, cws_container)
4. DO NOT include the `modified_container_definitions` logic that processes user containers
5. **Apply variable naming convention**: Remove `dd_` prefixes and follow the naming rules above
6. Update the version number in `main.tf` (local.version)
7. Test thoroughly with representative examples

## Source Attribution

This module is derived from:
- Repository: https://github.com/DataDog/terraform-aws-ecs-datadog
- Version: v1.0.6
- Module: `modules/ecs_fargate`
- License: Apache License Version 2.0

## Example Usage

See the README.md for complete usage examples.
