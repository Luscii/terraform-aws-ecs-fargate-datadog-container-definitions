# Terraform AWS ECS Fargate Datadog Container Definitions Module

## Overview

This module provides container definitions for ECS Fargate tasks with Datadog monitoring integration. It is based on the [DataDog/terraform-aws-ecs-datadog](https://github.com/DataDog/terraform-aws-ecs-datadog) module version v1.0.6, specifically extracted from the `modules/ecs_fargate` component.

## Purpose

Unlike the full DataDog module which creates a complete ECS task definition, this module **only** provides the container definitions JSON output. This allows you to:

- Use the container definitions in your own task definition resources
- Integrate Datadog monitoring without coupling to the DataDog module's task definition structure
- Maintain more control over your ECS task configuration while still benefiting from Datadog's container setup

## Key Features

This module automatically configures:

- **Datadog Agent Container**: Main monitoring agent with configurable CPU, memory, and health checks
- **Log Router Container** (optional): AWS Firelens/Fluent Bit integration for log forwarding to Datadog
- **CWS Container** (optional): Cloud Workload Security instrumentation for runtime security monitoring
- **Application Container Modifications**: Automatically adds necessary environment variables, volume mounts, and dependencies to your application containers for Datadog integration

## Container Definitions Output

The module provides two outputs:

1. `container_definitions` - JSON-encoded string ready to use in `aws_ecs_task_definition.container_definitions`
2. `container_definitions_list` - List of container definition objects for further manipulation

## What Gets Added to Your Containers

The module automatically enhances your application containers with:

- **Environment Variables**: 
  - APM socket URLs (`DD_TRACE_AGENT_URL`)
  - DogStatsD configuration (`DD_DOGSTATSD_URL`, `DD_AGENT_HOST`)
  - Unified Service Tagging (`DD_ENV`, `DD_SERVICE`, `DD_VERSION`)
  - Profiling and tracing settings

- **Volume Mounts**:
  - Datadog sockets volume (`/var/run/datadog`) for APM and DogStatsD
  - CWS instrumentation volume (when CWS is enabled)

- **Dependencies**:
  - Waits for Datadog agent to be healthy before starting
  - Waits for log router if enabled
  - Waits for CWS initialization if enabled

- **Docker Labels**: UST (Unified Service Tagging) labels for service, environment, and version

## Required Variables

At minimum, you must provide:

- `container_definitions` - Your application container definitions as JSON string
- Either `dd_api_key` or `dd_api_key_secret` - Datadog API credentials

## Important Notes

1. **API Key**: You must provide either `dd_api_key` (plaintext) or `dd_api_key_secret` (AWS Secrets Manager ARN), but not both
2. **Platform Support**: Some features like log collection and read-only root filesystem are only supported on Linux
3. **CWS Requirements**: Cloud Workload Security requires `dd_is_datadog_dependency_enabled = true` for stability
4. **No IAM Resources**: This module does NOT create IAM roles or policies - you must manage those separately
5. **No Task Definition**: This module does NOT create the task definition resource itself

## Updating This Module

This module is based on DataDog's official module. To update to a newer version:

1. Check the latest release at https://github.com/DataDog/terraform-aws-ecs-datadog/releases
2. Review the `modules/ecs_fargate/datadog.tf` file for container definition logic
3. Extract only the locals and logic related to container definitions
4. Update the version number in `main.tf` (local.version)
5. Test thoroughly with representative container definitions

## Source Attribution

This module is derived from:
- Repository: https://github.com/DataDog/terraform-aws-ecs-datadog
- Version: v1.0.6
- Module: `modules/ecs_fargate`
- License: Apache License Version 2.0

## Example Usage

See the README.md for complete usage examples.
