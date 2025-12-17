# terraform-aws-ecs-fargate-datadog-container-definitions

Module providing Datadog container definitions for ECS Fargate tasks.

## Examples

### Minimal Setup

```hcl
module "datadog_containers" {
  source = "github.com/Luscii/terraform-aws-ecs-fargate-datadog-container-definitions"

  dd_api_key_secret = {
    arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog-api-key"
  }
  
  dd_service = "my-service"
  dd_env     = "production"
}

# Define your application containers with Datadog integration
locals {
  app_containers = [
    {
      name      = "my-app"
      image     = "my-app:latest"
      cpu       = 256
      memory    = 512
      essential = true
      
      environment = [
        { name = "DD_TRACE_AGENT_URL", value = "unix:///var/run/datadog/apm.socket" },
        { name = "DD_DOGSTATSD_URL", value = "unix:///var/run/datadog/dsd.socket" },
        { name = "DD_ENV", value = "production" },
        { name = "DD_SERVICE", value = "my-service" },
        { name = "DD_VERSION", value = "1.0.0" }
      ]
      
      mountPoints = [
        {
          containerPath = "/var/run/datadog"
          sourceVolume  = "dd-sockets"
          readOnly      = false
        }
      ]
      
      dependsOn = [
        {
          containerName = "datadog-agent"
          condition     = "HEALTHY"
        }
      ]
      
      dockerLabels = {
        "com.datadoghq.tags.env"     = "production"
        "com.datadoghq.tags.service" = "my-service"
        "com.datadoghq.tags.version" = "1.0.0"
      }
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
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  
  container_definitions = jsonencode(
    concat(
      module.datadog_containers.datadog_containers,
      local.app_containers
    )
  )
  
  volume {
    name = "dd-sockets"
  }
}
```

### Advanced Setup with Log Collection and CWS

```hcl
module "datadog_containers" {
  source = "github.com/Luscii/terraform-aws-ecs-fargate-datadog-container-definitions"

  dd_api_key_secret = {
    arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog-api-key"
  }
  
  dd_service = "my-service"
  dd_env     = "production"
  dd_version = "1.0.0"
  
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
  
  # Enable CWS
  dd_cws = {
    enabled          = true
    cpu              = 128
    memory_limit_mib = 256
  }
  
  dd_is_datadog_dependency_enabled = true
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
      
      environment = [
        { name = "DD_TRACE_AGENT_URL", value = "unix:///var/run/datadog/apm.socket" },
        { name = "DD_DOGSTATSD_URL", value = "unix:///var/run/datadog/dsd.socket" },
        { name = "DD_ENV", value = "production" },
        { name = "DD_SERVICE", value = "my-service" },
        { name = "DD_VERSION", value = "1.0.0" }
      ]
      
      mountPoints = [
        {
          containerPath = "/var/run/datadog"
          sourceVolume  = "dd-sockets"
          readOnly      = false
        },
        {
          containerPath = "/cws-instrumentation-volume"
          sourceVolume  = "cws-instrumentation-volume"
          readOnly      = false
        }
      ]
      
      dependsOn = [
        {
          containerName = "datadog-agent"
          condition     = "HEALTHY"
        },
        {
          containerName = "cws-instrumentation-init"
          condition     = "SUCCESS"
        }
      ]
      
      linuxParameters = {
        capabilities = {
          add  = ["SYS_PTRACE"]
          drop = []
        }
      }
      
      dockerLabels = {
        "com.datadoghq.tags.env"     = "production"
        "com.datadoghq.tags.service" = "my-service"
        "com.datadoghq.tags.version" = "1.0.0"
      }
    }
  ]
}

resource "aws_ecs_task_definition" "this" {
  family                   = "my-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  
  container_definitions = jsonencode(
    concat(
      module.datadog_containers.datadog_containers,
      local.app_containers
    )
  )
  
  volume {
    name = "dd-sockets"
  }
  
  volume {
    name = "cws-instrumentation-volume"
  }
}
```

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
| <a name="output_datadog_agent_container"></a> [datadog\_agent\_container](#output\_datadog\_agent\_container) | The Datadog Agent container definition as a list of objects (includes init-volume container if read-only root filesystem is enabled) |
| <a name="output_datadog_containers"></a> [datadog\_containers](#output\_datadog\_containers) | All Datadog-related container definitions as a list of objects. Combine this with your application containers in your task definition. |
| <a name="output_datadog_containers_json"></a> [datadog\_containers\_json](#output\_datadog\_containers\_json) | All Datadog-related container definitions as a JSON-encoded string. Use this if you need a pre-encoded JSON string. |
| <a name="output_datadog_cws_container"></a> [datadog\_cws\_container](#output\_datadog\_cws\_container) | The Datadog Cloud Workload Security instrumentation container definition as a list of objects (empty list if CWS is disabled) |
| <a name="output_datadog_log_router_container"></a> [datadog\_log\_router\_container](#output\_datadog\_log\_router\_container) | The Datadog Log Router (Fluent Bit) container definition as a list of objects (empty list if log collection is disabled) |
<!-- END_TF_DOCS -->
