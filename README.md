# terraform-aws-ecs-fargate-datadog-container-definitions

Module providing Datadog container definitions for ECS Fargate tasks.

## Examples

### Minimal Setup

```hcl
module "datadog_containers" {
  source = "github.com/Luscii/terraform-aws-ecs-fargate-datadog-container-definitions"

  api_key = {
    value = "your-datadog-api-key"  # Or use value_from_arn for existing secret
  }

  service_name    = "my-service"
  stage           = "production"
  service_version = "1.0.0"
}

# Define your application containers using module outputs for automatic Datadog integration
locals {
  app_containers = [
    {
      name      = "my-app"
      image     = "my-app:latest"
      cpu       = 256
      memory    = 512
      essential = true

      # Automatic Datadog integration using module outputs
      environment    = module.datadog_containers.container_environment_variables
      mountPoints    = module.datadog_containers.container_mount_points
      dependsOn      = module.datadog_containers.container_depends_on
      dockerLabels   = module.datadog_containers.container_docker_labels
      logConfiguration = module.datadog_containers.container_log_configuration
    }
  ]
}

# Combine Datadog containers with your application containers
resource "aws_ecs_task_definition" "this" {
  family                   = "my-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode(
    concat(
      module.datadog_containers.datadog_containers,
      local.app_containers
    )
  )

  # Use module output for required volumes
  dynamic "volume" {
    for_each = module.datadog_containers.task_definition_volumes
    content {
      name = volume.value.name
    }
  }
}
```

### Using Existing Secret

```hcl
module "datadog_containers" {
  source = "github.com/Luscii/terraform-aws-ecs-fargate-datadog-container-definitions"

  api_key = {
    value_from_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog-api-key-abc123"
  }

  service_name    = "my-service"
  stage           = "production"
  service_version = "1.0.0"
}
```

### Advanced Setup with Log Collection and CWS

```hcl
module "datadog_containers" {
  source = "github.com/Luscii/terraform-aws-ecs-fargate-datadog-container-definitions"

  api_key = {
    value = var.datadog_api_key
  }

  service_name    = "my-service"
  stage           = "production"
  service_version = "1.0.0"

  # Optional: Use custom KMS key for secret encryption
  kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  # Enable log collection
  log_collection = {
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

  # Enable CWS
  cws = {
    enabled          = true
    cpu              = 128
    memory_limit_mib = 256
  }
}

locals {
  app_containers = [
    {
      name       = "my-app"
      image      = "my-app:latest"
      cpu        = 256
      memory     = 512
      essential  = true
      entryPoint = ["/usr/local/bin/docker-entrypoint.sh"]

      # Module outputs automatically include all required Datadog configuration
      # including CWS-specific mount points and dependencies
      environment  = module.datadog_containers.container_environment_variables
      mountPoints  = module.datadog_containers.container_mount_points
      dependsOn    = module.datadog_containers.container_depends_on
      dockerLabels = module.datadog_containers.container_docker_labels

      # CWS requires additional Linux parameters
      linuxParameters = {
        capabilities = {
          add  = ["SYS_PTRACE"]
          drop = []
        }
      }
    }
  ]
}
```

### Container Image Configuration

The module supports flexible container image configuration for all Datadog containers, with support for ECR pull-through cache to avoid Docker Hub rate limits.

#### Default Configuration (Amazon ECR Public)

By default, the Fluent Bit log router uses Amazon ECR Public (no authentication required, no rate limits):

```hcl
module "datadog_containers" {
  source = "github.com/Luscii/terraform-aws-ecs-fargate-datadog-container-definitions"

  # ... other configuration ...

  log_collection = {
    enabled = true
    fluentbit_config = {
      # Default log_router_image:
      #   repository: public.ecr.aws/aws-observability/aws-for-fluent-bit
      #   tag: stable
      log_driver_configuration = {
        service_name = "my-service"
      }
    }
  }
}
```

#### Using Docker Hub

To use Docker Hub instead (subject to rate limits):

```hcl
module "datadog_containers" {
  source = "github.com/Luscii/terraform-aws-ecs-fargate-datadog-container-definitions"

  # ... other configuration ...

  log_router_image = {
    repository        = "amazon/aws-for-fluent-bit"
    pull_cache_prefix = ""  # Empty = direct pull from Docker Hub
  }
  log_router_image_tag = "stable"
}
```

#### Using ECR Pull-Through Cache

To avoid rate limits and improve reliability, use ECR pull-through cache:

```hcl
module "datadog_containers" {
  source = "github.com/Luscii/terraform-aws-ecs-fargate-datadog-container-definitions"

  # ... other configuration ...

  # Datadog Agent via Docker Hub cache
  agent_image = {
    repository        = "datadog/agent"
    pull_cache_prefix = "docker-hub"  # ECR pull-through cache rule prefix
  }
  agent_image_tag = "7"

  # Fluent Bit via ECR Public cache
  log_router_image = {
    repository        = "aws-observability/aws-for-fluent-bit"
    pull_cache_prefix = "ecr-public"  # ECR pull-through cache rule prefix
  }
  log_router_image_tag = "stable"
}
```

**Note:** When using `pull_cache_prefix`, ensure you have created the corresponding ECR pull-through cache rules in your AWS account:
- `docker-hub` → `registry-1.docker.io`
- `ecr-public` → `public.ecr.aws`

```

resource "aws_ecs_task_definition" "this" {
  family                   = "my-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode(
    concat(
      module.datadog_containers.datadog_containers,
      local.app_containers
    )
  )

  # Module output automatically includes CWS volume when enabled
  dynamic "volume" {
    for_each = module.datadog_containers.task_definition_volumes
    content {
      name = volume.value.name
    }
  }
}
```

## Log Collection with Custom FluentBit Configuration

The module supports advanced log processing with custom FluentBit parsers and filters, enabling you to extract, transform, and enrich logs before sending them to Datadog.

### Overview

FluentBit log processing pipeline:
```
Container Logs → FluentBit → Custom Parsers → Custom Filters → Datadog
                     ↓              ↓                ↓
                 S3 Config    Extract Data    Transform/Enrich
```

### Basic Log Collection

Enable log collection with default configuration:

```hcl
module "datadog_containers" {
  source = "github.com/Luscii/terraform-aws-ecs-fargate-datadog-container-definitions"

  # ... other configuration ...

  log_collection = {
    enabled = true
    fluentbit_config = {
      cpu                     = 128
      memory_limit_mib        = 256
      is_log_router_essential = true
      log_driver_configuration = {
        service_name = "my-service"
        source_name  = "my-app"
      }
    }
  }
}
```

### Custom Parsers and Filters

For advanced log processing, define custom parsers and filters that will be automatically uploaded to S3 and loaded by FluentBit:

```hcl
resource "aws_s3_bucket" "fluentbit_config" {
  bucket = "my-fluentbit-config"
}

module "datadog_containers" {
  source = "github.com/Luscii/terraform-aws-ecs-fargate-datadog-container-definitions"

  # ... other configuration ...

  log_collection = {
    enabled = true
    fluentbit_config = {
      cpu                     = 128
      memory_limit_mib        = 256
      is_log_router_essential = true
    }
  }

  # S3 bucket for custom configuration files
  s3_config_bucket_name = aws_s3_bucket.fluentbit_config.id

  # Configuration file format (yaml for v3.x+, conf for v2.x)
  log_config_file_format = "yaml"

  # Custom parsers for extracting structured data
  log_config_parsers = [
    {
      name        = "json_parser"
      format      = "json"
      time_key    = "timestamp"
      time_format = "%Y-%m-%dT%H:%M:%S.%L"

      # Apply parser to Docker logs
      filter = {
        match        = "docker.*"
        key_name     = "log"
        reserve_data = true
      }
    },
    {
      name   = "custom_format"
      format = "regex"
      regex  = "^(?<time>[^ ]+) (?<level>[^ ]+) (?<message>.*)$"

      filter = {
        match        = "app.*"
        key_name     = "log"
        reserve_data = true
      }
    }
  ]

  # Custom filters for transforming and enriching logs
  log_config_filters = [
    # Add environment metadata
    {
      name = "modify"
      add_fields = {
        environment = "production"
        service     = "my-service"
      }
    },
    # Exclude health check logs
    {
      name    = "grep"
      match   = "docker.*"
      exclude = "health"
    },
    # Nest Kubernetes metadata
    {
      name          = "nest"
      operation     = "nest"
      wildcard      = ["kubernetes_*"]
      nest_under    = "kubernetes"
      remove_prefix = "kubernetes_"
    }
  ]
}
```

### Configuration File Format

The module supports both YAML (FluentBit v3.x+) and classic `.conf` (FluentBit v2.x) formats:

- **YAML format** (default, requires FluentBit v3.2.0+):
  ```hcl
  log_config_file_format = "yaml"
  log_router_image_tag   = "3.2.0"  # Default
  ```

- **Classic .conf format** (for FluentBit v2.x):
  ```hcl
  log_config_file_format = "conf"
  log_router_image_tag   = "2.34.2"
  ```

### FluentBit Init Process

When custom parsers or filters are configured, the module automatically:

1. **Generates configuration files** in YAML or .conf format
2. **Uploads to S3** with namespaced keys: `{module-path-id}/parsers.yaml` and `{module-path-id}/filters.yaml`
3. **Uses init-tagged FluentBit image** (e.g., `init-3.2.0`) for multi-config support
4. **Sets environment variables** for S3 config download:
   - `aws_fluent_bit_init_s3_1` → parsers config S3 ARN
   - `aws_fluent_bit_init_s3_2` → filters config S3 ARN

The FluentBit container downloads and loads these configurations on startup. See [AWS for Fluent Bit init process documentation](https://github.com/aws/aws-for-fluent-bit/blob/mainline/troubleshooting/debugging.md#using-init-tag-for-debug) for more details.

### Parser Options

Supported parser formats and their common options:

**JSON Parser:**
```hcl
{
  name        = "json_parser"
  format      = "json"
  time_key    = "timestamp"        # Field containing timestamp
  time_format = "%Y-%m-%dT%H:%M:%S.%L"
  time_keep   = true               # Keep original time field
}
```

**Regex Parser:**
```hcl
{
  name   = "custom_format"
  format = "regex"
  regex  = "^(?<field1>[^ ]+) (?<field2>[^ ]+)$"  # Capture groups become fields
}
```

**LTSV Parser** (tab-separated values):
```hcl
{
  name   = "ltsv_parser"
  format = "ltsv"
}
```

**Logfmt Parser** (key=value pairs):
```hcl
{
  name   = "logfmt_parser"
  format = "logfmt"
}
```

See [FluentBit Parsers Documentation](https://docs.fluentbit.io/manual/data-pipeline/parsers/configuring-parser) for all available options.

### Filter Options

Supported filter types:

**Parser Filter** (apply parsers to logs):
```hcl
{
  name         = "parser"
  parser       = "json_parser"     # Parser to apply
  match        = "docker.*"        # Tag pattern
  key_name     = "log"             # Field to parse
  reserve_data = true              # Keep other fields
}
```

**Grep Filter** (include/exclude logs):
```hcl
{
  name    = "grep"
  match   = "docker.*"
  regex   = "error"                # Include logs matching pattern
  exclude = "health"               # Exclude logs matching pattern
}
```

**Modify Filter** (add/rename/remove fields):
```hcl
{
  name = "modify"
  add_fields = {
    environment = "production"
    region      = "us-east-1"
  }
  rename_fields = {
    old_field = "new_field"
  }
  remove_fields = ["sensitive_field"]
}
```

**Nest Filter** (restructure data):
```hcl
{
  name          = "nest"
  operation     = "nest"           # or "lift"
  wildcard      = ["prefix_*"]
  nest_under    = "nested_object"
  remove_prefix = "prefix_"
}
```

See [FluentBit Filters Documentation](https://docs.fluentbit.io/manual/pipeline/filters) for all available filter types and options.

### Log Driver Configuration

Configure the FluentBit output to Datadog:

```hcl
log_collection = {
  enabled = true
  fluentbit_config = {
    log_driver_configuration = {
      host_endpoint = "http-intake.logs.datadoghq.eu"  # Override Datadog endpoint
      service_name  = "my-service"                     # Service name in Datadog
      source_name   = "my-app"                         # Source name in Datadog
      tls           = true                             # Use TLS (default: true)
      compress      = "gzip"                           # Compression (gzip/zlib)
      message_key   = "log"                            # JSON key for log message
    }
  }
}
```

Available options:
- `host_endpoint`: Datadog logs endpoint (defaults based on `site` variable)
- `service_name`: Service name tag in Datadog
- `source_name`: Source tag in Datadog
- `tls`: Enable TLS (default: true)
- `compress`: Compression algorithm (gzip, zlib)
- `message_key`: JSON field containing the log message

### Advanced Configuration

Additional FluentBit container options:

```hcl
log_collection = {
  enabled = true
  fluentbit_config = {
    cpu                              = 256
    memory_limit_mib                 = 512
    is_log_router_essential          = true
    is_log_router_dependency_enabled = true

    # Custom environment variables
    environment = [
      { name = "FLB_LOG_LEVEL", value = "debug" }
    ]

    # Health check configuration
    log_router_health_check = {
      command      = ["CMD-SHELL", "exit 0"]
      interval     = 5
      retries      = 3
      start_period = 15
      timeout      = 5
    }

    # Custom mount points
    mountPoints = [
      {
        sourceVolume  = "config"
        containerPath = "/fluent-bit/config"
        readOnly      = true
      }
    ]

    # Container dependencies
    dependsOn = [
      {
        containerName = "init"
        condition     = "SUCCESS"
      }
    ]
  }
}
```

### IAM Permissions

The module automatically includes S3 `GetObject` permissions in the `task_role_policy_json` output when custom parsers or filters are configured. Ensure your task role includes these permissions:

```hcl
data "aws_iam_policy_document" "task_combined" {
  source_policy_documents = [
    module.datadog_containers.task_role_policy_json,
    # Your additional policies...
  ]
}
```

The generated IAM policy includes:
- `s3:GetObject` permission for the config bucket
- `s3:GetBucketLocation` for bucket access
- Scoped to the specific S3 bucket containing FluentBit configurations

### Complete Example

For a complete working example with custom parsers and filters, see [examples/custom-logging](./examples/custom-logging).

### References

- [FluentBit Parsers Documentation](https://docs.fluentbit.io/manual/data-pipeline/parsers/configuring-parser)
- [FluentBit Filters Documentation](https://docs.fluentbit.io/manual/pipeline/filters)
- [FluentBit Parser Filter](https://docs.fluentbit.io/manual/pipeline/filters/parser)
- [AWS for Fluent Bit](https://github.com/aws/aws-for-fluent-bit)
- [AWS for Fluent Bit Init Process](https://github.com/aws/aws-for-fluent-bit/blob/mainline/troubleshooting/debugging.md#using-init-tag-for-debug)

## Required IAM Permissions

This module provides IAM policy documents as outputs that you can use in your IAM roles.

### Using Module-Generated IAM Policies

The module exposes IAM policy documents through outputs:

```hcl
module "datadog_containers" {
  source = "github.com/Luscii/terraform-aws-ecs-fargate-datadog-container-definitions"

  api_key = {
    value_from_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog-api-key"
  }
  service_name    = "my-service"
  stage           = "production"
  service_version = "1.0.0"

  # Optional: Scope ECS permissions to specific cluster
  ecs_cluster_arn = "arn:aws:ecs:us-east-1:123456789012:cluster/my-cluster"

  # Optional: Scope task permissions to specific task definition
  ecs_task_definition_arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/my-task"
}

# Merge Datadog policies into your task execution role
data "aws_iam_policy_document" "task_execution_combined" {
  source_policy_documents = compact([
    module.datadog_containers.task_execution_role_policy_json,
    # Add your other policy documents here
  ])
}

resource "aws_iam_role_policy" "task_execution" {
  name   = "task-execution-policy"
  role   = aws_iam_role.task_execution.id
  policy = data.aws_iam_policy_document.task_execution_combined.json
}

# Merge Datadog policies into your task role
data "aws_iam_policy_document" "task_combined" {
  source_policy_documents = [
    module.datadog_containers.task_role_policy_json,
    # Add your other policy documents here
  ]
}

resource "aws_iam_role_policy" "task" {
  name   = "task-policy"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_combined.json
}
```

### Task Execution Role

The task execution role must have:
- AWS managed policy: `AmazonECSTaskExecutionRolePolicy`
- Permission to access the Datadog API key secret

The module's `task_execution_role_policy_json` output includes permissions from the terraform-aws-service-secrets module for accessing secrets and SSM parameters.

### Task Role

The task role must have permissions for the Datadog agent to access ECS metadata.

The module's `task_role_policy_json` output includes:
- **DatadogECSMetadataAccess** (SID): Permissions to list and describe ECS resources
- **DatadogECSTaskDescribe** (SID): Permissions to describe tasks (only if `ecs_cluster_arn` is provided, for scoped access)

## Configuration

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6 |

### Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.28.0 |

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_label"></a> [label](#module\_label) | cloudposse/label/null | 0.25.0 |
| <a name="module_path"></a> [path](#module\_path) | cloudposse/label/null | 0.25.0 |
| <a name="module_service_secrets"></a> [service\_secrets](#module\_service\_secrets) | github.com/Luscii/terraform-aws-service-secrets | 1.2.1 |

### Resources

| Name | Type |
|------|------|
| [aws_s3_object.filters_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.parsers_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ecr_pull_through_cache_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_pull_through_cache_rule) | data source |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_cluster) | data source |
| [aws_iam_policy_document.execution_pull_cache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3_custom_config_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_s3_bucket.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |
| [aws_secretsmanager_secret.pull_through_cache_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_agent_cluster_name"></a> [agent\_cluster\_name](#input\_agent\_cluster\_name) | Override for the Datadog cluster name tag. When not set, the cluster name is automatically detected from ECS metadata API. Only set this if you want to use a different name in Datadog than the actual ECS cluster name. | `string` | `null` | no |
| <a name="input_agent_cpu"></a> [agent\_cpu](#input\_agent\_cpu) | Datadog Agent container CPU units | `number` | `null` | no |
| <a name="input_agent_docker_labels"></a> [agent\_docker\_labels](#input\_agent\_docker\_labels) | Datadog Agent container docker labels | `map(string)` | `{}` | no |
| <a name="input_agent_environment"></a> [agent\_environment](#input\_agent\_environment) | Datadog Agent container environment variables. Highest precedence and overwrites other environment variables defined by the module. For example, `agent_environment = [ { name = 'DD_VAR', value = 'DD_VAL' } ]` | `list(map(string))` | <pre>[<br/>  {}<br/>]</pre> | no |
| <a name="input_agent_essential"></a> [agent\_essential](#input\_agent\_essential) | Whether the Datadog Agent container is essential | `bool` | `false` | no |
| <a name="input_agent_health_check"></a> [agent\_health\_check](#input\_agent\_health\_check) | Datadog Agent health check configuration | <pre>object({<br/>    command      = optional(list(string))<br/>    interval     = optional(number)<br/>    retries      = optional(number)<br/>    start_period = optional(number)<br/>    timeout      = optional(number)<br/>  })</pre> | <pre>{<br/>  "command": [<br/>    "CMD-SHELL",<br/>    "/probe.sh"<br/>  ],<br/>  "interval": 15,<br/>  "retries": 3,<br/>  "start_period": 60,<br/>  "timeout": 5<br/>}</pre> | no |
| <a name="input_agent_image"></a> [agent\_image](#input\_agent\_image) | Datadog Agent container image configuration. The repository should be the path without registry or tag (e.g., 'datadog/agent'). When pull\_cache\_prefix is empty (default), images are pulled directly from their source registries (Docker Hub images are automatically resolved with 'docker.io/' prefix by the container runtime). Set pull\_cache\_prefix to your ECR pull-through cache rule prefix (e.g., 'docker-hub') when using ECR pull cache. The tag is specified separately in 'agent\_image\_tag'. | <pre>object({<br/>    repository        = optional(string, "datadog/agent")<br/>    pull_cache_prefix = optional(string, "")<br/>  })</pre> | `{}` | no |
| <a name="input_agent_image_tag"></a> [agent\_image\_tag](#input\_agent\_image\_tag) | Datadog Agent container image tag | `string` | `"7"` | no |
| <a name="input_agent_memory_limit_mib"></a> [agent\_memory\_limit\_mib](#input\_agent\_memory\_limit\_mib) | Datadog Agent container memory limit in MiB | `number` | `null` | no |
| <a name="input_agent_readonly_root_filesystem"></a> [agent\_readonly\_root\_filesystem](#input\_agent\_readonly\_root\_filesystem) | Datadog Agent container runs with read-only root filesystem enabled | `bool` | `false` | no |
| <a name="input_agent_tags"></a> [agent\_tags](#input\_agent\_tags) | Datadog Agent global tags (eg. `key1:value1, key2:value2`) | `string` | `null` | no |
| <a name="input_api_key"></a> [api\_key](#input\_api\_key) | Datadog API Key configuration. Provide either 'value' for plaintext key or 'value\_from\_arn' for existing secret ARN. When neither is provided, a new secret will be created. | <pre>object({<br/>    value          = optional(string)<br/>    value_from_arn = optional(string)<br/>    description    = optional(string, "Datadog API Key")<br/>  })</pre> | `null` | no |
| <a name="input_apm"></a> [apm](#input\_apm) | Configuration for Datadog APM | <pre>object({<br/>    enabled                       = optional(bool, true)<br/>    socket_enabled                = optional(bool, true)<br/>    profiling                     = optional(bool, false)<br/>    trace_inferred_proxy_services = optional(bool, false)<br/>  })</pre> | <pre>{<br/>  "enabled": true,<br/>  "profiling": false,<br/>  "socket_enabled": true,<br/>  "trace_inferred_proxy_services": false<br/>}</pre> | no |
| <a name="input_container_mount_path_prefix"></a> [container\_mount\_path\_prefix](#input\_container\_mount\_path\_prefix) | Prefix path for container mount points. Datadog sockets will be mounted at this prefix + 'datadog'. | `string` | `"/var/run/"` | no |
| <a name="input_context"></a> [context](#input\_context) | Single object for setting entire context at once.<br/>See description of individual variables for details.<br/>Leave string and numeric variables as `null` to use default value.<br/>Individual variable settings (non-null) override settings in context object,<br/>except for attributes, tags, and additional\_tag\_map, which are merged. | `any` | <pre>{<br/>  "additional_tag_map": {},<br/>  "attributes": [],<br/>  "delimiter": null,<br/>  "descriptor_formats": {},<br/>  "enabled": true,<br/>  "environment": null,<br/>  "id_length_limit": null,<br/>  "label_key_case": null,<br/>  "label_order": [],<br/>  "label_value_case": null,<br/>  "labels_as_tags": [<br/>    "unset"<br/>  ],<br/>  "name": null,<br/>  "namespace": null,<br/>  "regex_replace_chars": null,<br/>  "stage": null,<br/>  "tags": {},<br/>  "tenant": null<br/>}</pre> | no |
| <a name="input_cws"></a> [cws](#input\_cws) | Configuration for Datadog Cloud Workload Security (CWS) | <pre>object({<br/>    enabled          = optional(bool, false)<br/>    cpu              = optional(number)<br/>    memory_limit_mib = optional(number)<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_cws_image"></a> [cws\_image](#input\_cws\_image) | Datadog Cloud Workload Security (CWS) instrumentation container image configuration. The repository should be the path without registry or tag (e.g., 'datadog/cws-instrumentation'). When pull\_cache\_prefix is empty (default), images are pulled directly from their source registries (Docker Hub images are automatically resolved with 'docker.io/' prefix by the container runtime). Set pull\_cache\_prefix to your ECR pull-through cache rule prefix (e.g., 'docker-hub') when using ECR pull cache. The tag is specified separately in 'cws\_image\_tag'. | <pre>object({<br/>    repository        = optional(string, "datadog/cws-instrumentation")<br/>    pull_cache_prefix = optional(string, "")<br/>  })</pre> | `{}` | no |
| <a name="input_cws_image_tag"></a> [cws\_image\_tag](#input\_cws\_image\_tag) | Datadog Cloud Workload Security (CWS) instrumentation container image tag | `string` | `"7.73.0"` | no |
| <a name="input_dogstatsd"></a> [dogstatsd](#input\_dogstatsd) | Configuration for Datadog DogStatsD | <pre>object({<br/>    enabled                  = optional(bool, true)<br/>    origin_detection_enabled = optional(bool, true)<br/>    dogstatsd_cardinality    = optional(string, "orchestrator")<br/>    socket_enabled           = optional(bool, true)<br/>  })</pre> | <pre>{<br/>  "dogstatsd_cardinality": "orchestrator",<br/>  "enabled": true,<br/>  "origin_detection_enabled": true,<br/>  "socket_enabled": true<br/>}</pre> | no |
| <a name="input_ecs_cluster_name"></a> [ecs\_cluster\_name](#input\_ecs\_cluster\_name) | ARN of the ECS cluster. When provided, IAM policies will be scoped to this cluster. If not provided, policies will use wildcard resources. | `string` | `null` | no |
| <a name="input_ecs_task_definition_arn"></a> [ecs\_task\_definition\_arn](#input\_ecs\_task\_definition\_arn) | ARN of the ECS task definition. When provided, task-specific IAM permissions will be scoped to this task definition. Use with ecs\_cluster\_arn for granular permissions. | `string` | `null` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS Key identifier to encrypt Datadog API key secret if a new secret is created. Can be in any of the formats: Key ID, Key ARN, Alias Name, Alias ARN | `string` | `null` | no |
| <a name="input_log_collection"></a> [log\_collection](#input\_log\_collection) | Configuration for Datadog Log Collection | <pre>object({<br/>    enabled = optional(bool, false)<br/>    fluentbit_config = optional(object({<br/>      cpu                              = optional(number)<br/>      memory_limit_mib                 = optional(number)<br/>      is_log_router_essential          = optional(bool, false)<br/>      is_log_router_dependency_enabled = optional(bool, false)<br/>      environment = optional(list(object({<br/>        name  = string<br/>        value = string<br/>      })), [])<br/>      log_router_health_check = optional(object({<br/>        command      = optional(list(string))<br/>        interval     = optional(number)<br/>        retries      = optional(number)<br/>        start_period = optional(number)<br/>        timeout      = optional(number)<br/>        }),<br/>        {<br/>          command      = ["CMD-SHELL", "exit 0"]<br/>          interval     = 5<br/>          retries      = 3<br/>          start_period = 15<br/>          timeout      = 5<br/>        }<br/>      )<br/>      firelens_options = optional(object({<br/>        config_file_type  = optional(string)<br/>        config_file_value = optional(string)<br/>      }))<br/>      log_driver_configuration = optional(object({<br/>        host_endpoint = optional(string)<br/>        tls           = optional(bool)<br/>        compress      = optional(string)<br/>        service_name  = optional(string)<br/>        source_name   = optional(string)<br/>        message_key   = optional(string)<br/>        }),<br/>        {}<br/>      )<br/>      log_router_log_configuration = optional(object({<br/>        logDriver = optional(string, "awslogs")<br/>        options   = optional(map(string), {})<br/>        secretOptions = optional(list(object({<br/>          name      = string<br/>          valueFrom = string<br/>        })), [])<br/>        }),<br/>        {<br/>          logDriver = "awslogs"<br/>          options   = {}<br/>        }<br/>      )<br/>      mountPoints = optional(list(object({<br/>        sourceVolume : string,<br/>        containerPath : string,<br/>        readOnly : bool<br/>      })), [])<br/>      dependsOn = optional(list(object({<br/>        containerName : string,<br/>        condition : string<br/>      })), [])<br/>      }),<br/>      {}<br/>    )<br/>  })</pre> | <pre>{<br/>  "enabled": false,<br/>  "fluentbit_config": {<br/>    "is_log_router_essential": false,<br/>    "log_driver_configuration": {}<br/>  }<br/>}</pre> | no |
| <a name="input_log_config_file_format"></a> [log\_config\_file\_format](#input\_log\_config\_file\_format) | Datadog log collection configuration file format when using S3 config bucket. Valid values are 'yaml' or 'conf'. Note: YAML format requires Fluent Bit version 3.x or higher (controlled by log\_router\_image\_tag). Version 2.x only supports 'conf' format. | `string` | `"yaml"` | no |
| <a name="input_log_config_filters"></a> [log\_config\_filters](#input\_log\_config\_filters) | Custom filter definitions for Fluent Bit log processing. Filters can modify, enrich, or drop log records. Common filter types include grep (include/exclude), modify (add/rename/remove fields), nest (restructure data), and kubernetes (enrich with K8s metadata). See: https://docs.fluentbit.io/manual/pipeline/filters | <pre>list(object({<br/>    name  = string<br/>    match = optional(string) # Tag pattern to match (e.g., 'docker.*', 'app.logs')<br/>    # Parser filter options<br/>    parser       = optional(string)      # Parser name to apply<br/>    key_name     = optional(string)      # Field name to parse (required for parser filter)<br/>    reserve_data = optional(bool, false) # Preserve all other fields in the record<br/>    preserve_key = optional(bool, false) # Keep the original key field after parsing<br/>    unescape_key = optional(bool, false) # Unescape the key field before parsing<br/>    # Grep filter options<br/>    regex   = optional(string) # Regex pattern to match<br/>    exclude = optional(string) # Regex pattern to exclude<br/>    # Modify filter options<br/>    add_fields    = optional(map(string))  # Fields to add<br/>    rename_fields = optional(map(string))  # Fields to rename (old_name = new_name)<br/>    remove_fields = optional(list(string)) # Fields to remove<br/>    # Nest filter options<br/>    operation     = optional(string)       # nest or lift<br/>    wildcard      = optional(list(string)) # Wildcard patterns<br/>    nest_under    = optional(string)       # Target field for nesting<br/>    nested_under  = optional(string)       # Source field for lifting<br/>    remove_prefix = optional(string)       # Prefix to remove from keys<br/>    add_prefix    = optional(string)       # Prefix to add to keys<br/>  }))</pre> | `[]` | no |
| <a name="input_log_config_parsers"></a> [log\_config\_parsers](#input\_log\_config\_parsers) | Custom parser definitions for Fluent Bit log processing. Each parser can extract and transform log data using formats like json, regex, ltsv, or logfmt. The optional filter section controls when and how the parser is applied to log records. Required for Fluent Bit v3.x YAML configurations. See: https://docs.fluentbit.io/manual/data-pipeline/parsers/configuring-parser and https://docs.fluentbit.io/manual/pipeline/filters/parser | <pre>list(object({<br/>    name   = string<br/>    format = string<br/>    # JSON parser options<br/>    time_key    = optional(string)<br/>    time_format = optional(string)<br/>    time_keep   = optional(bool)<br/>    # Regex parser options<br/>    regex = optional(string)<br/>    # LTSV parser options (tab-separated values)<br/>    # Logfmt parser options<br/>    # Decoder options<br/>    decode_field    = optional(string)<br/>    decode_field_as = optional(string)<br/>    # Type casting<br/>    types = optional(string)<br/>    # Additional options<br/>    skip_empty_values = optional(bool)<br/>    # Filter configuration - controls when and how this parser is applied<br/>    filter = optional(object({<br/>      match        = optional(string)      # Tag pattern to match (e.g., 'docker.*', 'app.logs')<br/>      key_name     = optional(string)      # Field name to parse (e.g., 'log', 'message')<br/>      reserve_data = optional(bool, false) # Preserve all other fields in the record<br/>      preserve_key = optional(bool, false) # Keep the original key field after parsing<br/>      unescape_key = optional(bool, false) # Unescape the key field before parsing<br/>    }))<br/>  }))</pre> | `[]` | no |
| <a name="input_log_router_image"></a> [log\_router\_image](#input\_log\_router\_image) | Fluent Bit log router container image configuration. The repository should be the full image path including registry when pull\_cache\_prefix is empty, or just the repository path when using ECR pull-through cache. Default uses Amazon ECR Public. Examples: 'public.ecr.aws/aws-observability/aws-for-fluent-bit' (ECR Public, no cache), 'amazon/aws-for-fluent-bit' (Docker Hub, no cache), 'aws-observability/aws-for-fluent-bit' (with pull\_cache\_prefix='ecr-public'). The tag is specified separately in 'log\_router\_image\_tag'. | <pre>object({<br/>    repository        = optional(string, "public.ecr.aws/aws-observability/aws-for-fluent-bit")<br/>    pull_cache_prefix = optional(string, "")<br/>  })</pre> | `{}` | no |
| <a name="input_log_router_image_tag"></a> [log\_router\_image\_tag](#input\_log\_router\_image\_tag) | Fluent Bit log router container image tag. Version 3.x+ supports YAML configuration files, version 2.x only supports classic .conf format. Use specific version tags (e.g., '3.2.0', '2.34.2') instead of mutable tags like 'stable' or '3' for production deployments. | `string` | `"3.2.0"` | no |
| <a name="input_parameters"></a> [parameters](#input\_parameters) | Map of parameters for the Datadog containers, each key will be the name. When the value is set, a parameter is created. Otherwise the arn of existing parameter is added to the outputs. | <pre>map(<br/>    object({<br/>      data_type      = optional(string, "text")<br/>      description    = optional(string)<br/>      sensitive      = optional(bool, false)<br/>      tier           = optional(string, "Advanced")<br/>      value          = optional(string)<br/>      value_from_arn = optional(string)<br/>    })<br/>  )</pre> | `{}` | no |
| <a name="input_runtime_platform"></a> [runtime\_platform](#input\_runtime\_platform) | Configuration for `runtime_platform` that containers in your task may use | <pre>object({<br/>    cpu_architecture        = optional(string, "X86_64")<br/>    operating_system_family = optional(string, "LINUX")<br/>  })</pre> | <pre>{<br/>  "cpu_architecture": "X86_64",<br/>  "operating_system_family": "LINUX"<br/>}</pre> | no |
| <a name="input_s3_config_bucket_name"></a> [s3\_config\_bucket\_name](#input\_s3\_config\_bucket\_name) | Datadog S3 Config Bucket Name for log collection configuration | `string` | `null` | no |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Map of secrets for the Datadog containers, each key will be the name. When the value is set, a secret is created. Otherwise the arn of existing secret is added to the outputs. | <pre>map(object({<br/>    value          = optional(string)<br/>    description    = optional(string)<br/>    value_from_arn = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | The service name for Datadog Unified Service Tagging (UST). Sets the `DD_SERVICE` environment variable and `com.datadoghq.tags.service` Docker label. Should identify the service across all environments (e.g., 'web-api', 'payment-service'). | `string` | n/a | yes |
| <a name="input_service_version"></a> [service\_version](#input\_service\_version) | The version identifier for Datadog Unified Service Tagging (UST). Sets the `DD_VERSION` environment variable and `com.datadoghq.tags.version` Docker label. Should identify the application version (e.g., 'v1.2.3', git commit SHA). | `string` | n/a | yes |
| <a name="input_site"></a> [site](#input\_site) | Datadog Site | `string` | `"datadoghq.com"` | no |
| <a name="input_stage"></a> [stage](#input\_stage) | The environment/stage name for Datadog Unified Service Tagging (UST). Sets the `DD_ENV` environment variable and `com.datadoghq.tags.env` Docker label. Should identify the deployment environment (e.g., 'production', 'staging', 'dev'). | `string` | `null` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_depends_on"></a> [container\_depends\_on](#output\_container\_depends\_on) | List of container dependencies to add to application containers. Ensures Datadog agent (and log router/CWS if enabled) are ready before application starts. |
| <a name="output_container_docker_labels"></a> [container\_docker\_labels](#output\_container\_docker\_labels) | Map of Docker labels to add to application containers for Unified Service Tagging. Includes env, service, and version labels. |
| <a name="output_container_environment_variables"></a> [container\_environment\_variables](#output\_container\_environment\_variables) | List of environment variables to add to application containers for Datadog integration. Includes DD\_TRACE\_AGENT\_URL, DD\_DOGSTATSD\_URL (if socket-based), and Unified Service Tagging variables. |
| <a name="output_container_log_configuration"></a> [container\_log\_configuration](#output\_container\_log\_configuration) | Log configuration object to add to application containers for Datadog log collection via FireLens. Returns null if log collection is disabled. Use this in your container definitions' logConfiguration field to send logs to Datadog. |
| <a name="output_container_mount_points"></a> [container\_mount\_points](#output\_container\_mount\_points) | List of mount points to add to application containers for Datadog integration. Includes Datadog socket volume and CWS instrumentation volume (if enabled). |
| <a name="output_context"></a> [context](#output\_context) | Context output from CloudPosse label module for passing to nested modules |
| <a name="output_datadog_agent_container"></a> [datadog\_agent\_container](#output\_datadog\_agent\_container) | The Datadog Agent container definition as a list of objects (includes init-volume container if read-only root filesystem is enabled) |
| <a name="output_datadog_containers"></a> [datadog\_containers](#output\_datadog\_containers) | All Datadog-related container definitions as a list of objects. Combine this with your application containers in your task definition. |
| <a name="output_datadog_containers_json"></a> [datadog\_containers\_json](#output\_datadog\_containers\_json) | All Datadog-related container definitions as a JSON-encoded string. Use this if you need a pre-encoded JSON string. |
| <a name="output_datadog_cws_container"></a> [datadog\_cws\_container](#output\_datadog\_cws\_container) | The Datadog Cloud Workload Security instrumentation container definition as a list of objects (empty list if CWS is disabled) |
| <a name="output_datadog_log_router_container"></a> [datadog\_log\_router\_container](#output\_datadog\_log\_router\_container) | The Datadog Log Router (Fluent Bit) container definition as a list of objects (empty list if log collection is disabled) |
| <a name="output_filters_config_s3_key"></a> [filters\_config\_s3\_key](#output\_filters\_config\_s3\_key) | S3 object key for the FluentBit filters configuration file. Returns null if no filters are configured. |
| <a name="output_parsers_config_s3_key"></a> [parsers\_config\_s3\_key](#output\_parsers\_config\_s3\_key) | S3 object key for the FluentBit parsers configuration file. Returns null if no custom parsers are configured. |
| <a name="output_pull_cache_prefixes"></a> [pull\_cache\_prefixes](#output\_pull\_cache\_prefixes) | Set of unique ECR pull cache prefixes used by Datadog containers. Use this to set up ECR pull through cache rules and IAM policies in the calling module. |
| <a name="output_pull_cache_rule_arns"></a> [pull\_cache\_rule\_arns](#output\_pull\_cache\_rule\_arns) | Map of ECR pull cache rule ARNs keyed by pull cache prefix. Use this to configure IAM policies if needed. |
| <a name="output_pull_cache_rule_urls"></a> [pull\_cache\_rule\_urls](#output\_pull\_cache\_rule\_urls) | Map of ECR pull cache rule URLs keyed by pull cache prefix. Use this to configure container image URLs in Datadog container definitions. |
| <a name="output_task_definition_volumes"></a> [task\_definition\_volumes](#output\_task\_definition\_volumes) | List of volume definitions to add to the ECS task definition. Includes dd-sockets volume (if APM/DogStatsD sockets enabled) and cws-instrumentation-volume (if CWS is enabled). |
| <a name="output_task_execution_role_policy_json"></a> [task\_execution\_role\_policy\_json](#output\_task\_execution\_role\_policy\_json) | IAM policy document JSON for the task execution role. Include this in your task execution role to grant access to Datadog secrets. Returns empty string if no secret is configured. |
| <a name="output_task_role_policy_json"></a> [task\_role\_policy\_json](#output\_task\_role\_policy\_json) | IAM policy document JSON for the task role. Include this in your task role to grant Datadog agent access to ECS metadata. |
<!-- END_TF_DOCS -->
