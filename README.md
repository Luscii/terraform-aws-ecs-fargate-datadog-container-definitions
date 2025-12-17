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
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.9 |

### Providers

No providers.

### Modules

No modules.

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container_definitions"></a> [container\_definitions](#input\_container\_definitions) | A list of valid [container definitions](http://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html). Please note that you should only provide values that are part of the container definition document | `any` | n/a | yes |
| <a name="input_dd_api_key"></a> [dd\_api\_key](#input\_dd\_api\_key) | Datadog API Key | `string` | `null` | no |
| <a name="input_dd_api_key_secret"></a> [dd\_api\_key\_secret](#input\_dd\_api\_key\_secret) | Datadog API Key Secret ARN | <pre>object({<br/>    arn = string<br/>  })</pre> | `null` | no |
| <a name="input_dd_apm"></a> [dd\_apm](#input\_dd\_apm) | Configuration for Datadog APM | <pre>object({<br/>    enabled                       = optional(bool, true)<br/>    socket_enabled                = optional(bool, true)<br/>    profiling                     = optional(bool, false)<br/>    trace_inferred_proxy_services = optional(bool, false)<br/>  })</pre> | <pre>{<br/>  "enabled": true,<br/>  "profiling": false,<br/>  "socket_enabled": true,<br/>  "trace_inferred_proxy_services": false<br/>}</pre> | no |
| <a name="input_dd_checks_cardinality"></a> [dd\_checks\_cardinality](#input\_dd\_checks\_cardinality) | Datadog Agent checks cardinality | `string` | `null` | no |
| <a name="input_dd_cluster_name"></a> [dd\_cluster\_name](#input\_dd\_cluster\_name) | Datadog cluster name | `string` | `null` | no |
| <a name="input_dd_cpu"></a> [dd\_cpu](#input\_dd\_cpu) | Datadog Agent container CPU units | `number` | `null` | no |
| <a name="input_dd_cws"></a> [dd\_cws](#input\_dd\_cws) | Configuration for Datadog Cloud Workload Security (CWS) | <pre>object({<br/>    enabled          = optional(bool, false)<br/>    cpu              = optional(number)<br/>    memory_limit_mib = optional(number)<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_dd_docker_labels"></a> [dd\_docker\_labels](#input\_dd\_docker\_labels) | Datadog Agent container docker labels | `map(string)` | `{}` | no |
| <a name="input_dd_dogstatsd"></a> [dd\_dogstatsd](#input\_dd\_dogstatsd) | Configuration for Datadog DogStatsD | <pre>object({<br/>    enabled                  = optional(bool, true)<br/>    origin_detection_enabled = optional(bool, true)<br/>    dogstatsd_cardinality    = optional(string, "orchestrator")<br/>    socket_enabled           = optional(bool, true)<br/>  })</pre> | <pre>{<br/>  "dogstatsd_cardinality": "orchestrator",<br/>  "enabled": true,<br/>  "origin_detection_enabled": true,<br/>  "socket_enabled": true<br/>}</pre> | no |
| <a name="input_dd_env"></a> [dd\_env](#input\_dd\_env) | The task environment name. Used for tagging (UST) | `string` | `null` | no |
| <a name="input_dd_environment"></a> [dd\_environment](#input\_dd\_environment) | Datadog Agent container environment variables. Highest precedence and overwrites other environment variables defined by the module. For example, `dd_environment = [ { name = 'DD_VAR', value = 'DD_VAL' } ]` | `list(map(string))` | <pre>[<br/>  {}<br/>]</pre> | no |
| <a name="input_dd_essential"></a> [dd\_essential](#input\_dd\_essential) | Whether the Datadog Agent container is essential | `bool` | `false` | no |
| <a name="input_dd_health_check"></a> [dd\_health\_check](#input\_dd\_health\_check) | Datadog Agent health check configuration | <pre>object({<br/>    command      = optional(list(string))<br/>    interval     = optional(number)<br/>    retries      = optional(number)<br/>    start_period = optional(number)<br/>    timeout      = optional(number)<br/>  })</pre> | <pre>{<br/>  "command": [<br/>    "CMD-SHELL",<br/>    "/probe.sh"<br/>  ],<br/>  "interval": 15,<br/>  "retries": 3,<br/>  "start_period": 60,<br/>  "timeout": 5<br/>}</pre> | no |
| <a name="input_dd_image_version"></a> [dd\_image\_version](#input\_dd\_image\_version) | Datadog Agent image version | `string` | `"latest"` | no |
| <a name="input_dd_is_datadog_dependency_enabled"></a> [dd\_is\_datadog\_dependency\_enabled](#input\_dd\_is\_datadog\_dependency\_enabled) | Whether the Datadog Agent container is a dependency for other containers | `bool` | `false` | no |
| <a name="input_dd_log_collection"></a> [dd\_log\_collection](#input\_dd\_log\_collection) | Configuration for Datadog Log Collection | <pre>object({<br/>    enabled = optional(bool, false)<br/>    fluentbit_config = optional(object({<br/>      registry                         = optional(string, "public.ecr.aws/aws-observability/aws-for-fluent-bit")<br/>      image_version                    = optional(string, "stable")<br/>      cpu                              = optional(number)<br/>      memory_limit_mib                 = optional(number)<br/>      is_log_router_essential          = optional(bool, false)<br/>      is_log_router_dependency_enabled = optional(bool, false)<br/>      environment = optional(list(object({<br/>        name  = string<br/>        value = string<br/>      })), [])<br/>      log_router_health_check = optional(object({<br/>        command      = optional(list(string))<br/>        interval     = optional(number)<br/>        retries      = optional(number)<br/>        start_period = optional(number)<br/>        timeout      = optional(number)<br/>        }),<br/>        {<br/>          command      = ["CMD-SHELL", "exit 0"]<br/>          interval     = 5<br/>          retries      = 3<br/>          start_period = 15<br/>          timeout      = 5<br/>        }<br/>      )<br/>      firelens_options = optional(object({<br/>        config_file_type  = optional(string)<br/>        config_file_value = optional(string)<br/>      }))<br/>      log_driver_configuration = optional(object({<br/>        host_endpoint = optional(string, "http-intake.logs.datadoghq.com")<br/>        tls           = optional(bool)<br/>        compress      = optional(string)<br/>        service_name  = optional(string)<br/>        source_name   = optional(string)<br/>        message_key   = optional(string)<br/>        }),<br/>        {<br/>          host_endpoint = "http-intake.logs.datadoghq.com"<br/>        }<br/>      )<br/>      mountPoints = optional(list(object({<br/>        sourceVolume : string,<br/>        containerPath : string,<br/>        readOnly : bool<br/>      })), [])<br/>      dependsOn = optional(list(object({<br/>        containerName : string,<br/>        condition : string<br/>      })), [])<br/>      }),<br/>      {<br/>        fluentbit_config = {<br/>          registry      = "public.ecr.aws/aws-observability/aws-for-fluent-bit"<br/>          image_version = "stable"<br/>          log_driver_configuration = {<br/>            host_endpoint = "http-intake.logs.datadoghq.com"<br/>          }<br/>        }<br/>      }<br/>    )<br/>  })</pre> | <pre>{<br/>  "enabled": false,<br/>  "fluentbit_config": {<br/>    "is_log_router_essential": false,<br/>    "log_driver_configuration": {<br/>      "host_endpoint": "http-intake.logs.datadoghq.com"<br/>    }<br/>  }<br/>}</pre> | no |
| <a name="input_dd_memory_limit_mib"></a> [dd\_memory\_limit\_mib](#input\_dd\_memory\_limit\_mib) | Datadog Agent container memory limit in MiB | `number` | `null` | no |
| <a name="input_dd_readonly_root_filesystem"></a> [dd\_readonly\_root\_filesystem](#input\_dd\_readonly\_root\_filesystem) | Datadog Agent container runs with read-only root filesystem enabled | `bool` | `false` | no |
| <a name="input_dd_registry"></a> [dd\_registry](#input\_dd\_registry) | Datadog Agent image registry | `string` | `"public.ecr.aws/datadog/agent"` | no |
| <a name="input_dd_service"></a> [dd\_service](#input\_dd\_service) | The task service name. Used for tagging (UST) | `string` | `null` | no |
| <a name="input_dd_site"></a> [dd\_site](#input\_dd\_site) | Datadog Site | `string` | `"datadoghq.com"` | no |
| <a name="input_dd_tags"></a> [dd\_tags](#input\_dd\_tags) | Datadog Agent global tags (eg. `key1:value1, key2:value2`) | `string` | `null` | no |
| <a name="input_dd_version"></a> [dd\_version](#input\_dd\_version) | The task version name. Used for tagging (UST) | `string` | `null` | no |
| <a name="input_runtime_platform"></a> [runtime\_platform](#input\_runtime\_platform) | Configuration for `runtime_platform` that containers in your task may use | <pre>object({<br/>    cpu_architecture        = optional(string, "X86_64")<br/>    operating_system_family = optional(string, "LINUX")<br/>  })</pre> | <pre>{<br/>  "cpu_architecture": "X86_64",<br/>  "operating_system_family": "LINUX"<br/>}</pre> | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_definitions"></a> [container\_definitions](#output\_container\_definitions) | A list of valid container definitions provided as a single valid JSON document. This includes Datadog Agent, Log Router, CWS containers, and modified application containers. |
| <a name="output_container_definitions_list"></a> [container\_definitions\_list](#output\_container\_definitions\_list) | The container definitions as a list of objects (not JSON encoded). Useful for further manipulation or inspection. |
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
