# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

################################################################################
# CloudPosse Label Context
################################################################################

variable "context" {
  type = any
  default = {
    enabled             = true
    namespace           = null
    tenant              = null
    environment         = null
    stage               = null
    name                = null
    delimiter           = null
    attributes          = []
    tags                = {}
    additional_tag_map  = {}
    regex_replace_chars = null
    label_order         = []
    id_length_limit     = null
    label_key_case      = null
    label_value_case    = null
    descriptor_formats  = {}
    labels_as_tags      = ["unset"]
  }
  description = <<-EOT
    Single object for setting entire context at once.
    See description of individual variables for details.
    Leave string and numeric variables as `null` to use default value.
    Individual variable settings (non-null) override settings in context object,
    except for attributes, tags, and additional_tag_map, which are merged.
  EOT

  validation {
    condition     = lookup(var.context, "label_key_case", null) == null ? true : contains(["lower", "title", "upper"], var.context["label_key_case"])
    error_message = "Allowed values: `lower`, `title`, `upper`."
  }

  validation {
    condition     = lookup(var.context, "label_value_case", null) == null ? true : contains(["lower", "title", "upper", "none"], var.context["label_value_case"])
    error_message = "Allowed values: `lower`, `title`, `upper`, `none`."
  }
}

################################################################################
# Datadog ECS Fargate Configuration
################################################################################

variable "api_key" {
  description = "Datadog API Key configuration. Provide either 'value' for plaintext key or 'value_from_arn' for existing secret ARN. When neither is provided, a new secret will be created."
  type = object({
    value          = optional(string)
    value_from_arn = optional(string)
    description    = optional(string, "Datadog API Key")
  })
  sensitive = true
  default   = null

  validation {
    condition = (
      var.api_key == null ||
      (var.api_key.value != null && var.api_key.value_from_arn == null) ||
      (var.api_key.value == null && var.api_key.value_from_arn != null)
    )
    error_message = "Only one of 'value' or 'value_from_arn' can be set, not both."
  }

  validation {
    condition = (
      var.api_key == null ||
      var.api_key.value_from_arn == null ||
      can(regex("^arn:aws:secretsmanager:[a-zA-Z0-9-]+:[0-9]{12}:secret:[a-zA-Z0-9-_/]+-[a-zA-Z0-9]{6}$", var.api_key.value_from_arn))
    )
    error_message = "The value_from_arn must be a valid Secrets Manager ARN with format: arn:aws:secretsmanager:region:account-id:secret:secret-name-suffix"
  }
}

variable "secrets" {
  type = map(object({
    value          = optional(string)
    description    = optional(string)
    value_from_arn = optional(string)
  }))
  sensitive   = true
  description = "Map of secrets for the Datadog containers, each key will be the name. When the value is set, a secret is created. Otherwise the arn of existing secret is added to the outputs."
  default     = {}

  validation {
    condition = alltrue([
      for key, value in var.secrets : contains(keys(value), "value") || contains(keys(value), "value_from_arn")
    ])
    error_message = "value or value_from_arn must be set for each secret"
  }

  validation {
    condition = alltrue([
      for key, value in var.secrets : value.value != null && value.value_from_arn != null ? false : true
    ])
    error_message = "value and value_from_arn cannot be set at the same time"
  }

  validation {
    condition = alltrue([
      for key, value in var.secrets :
      value.value_from_arn == null ? true :
      length(regexall("^arn:aws:secretsmanager:[a-zA-Z0-9-]+:[0-9]{12}:secret:[a-zA-Z0-9-_/]+-[a-zA-Z0-9]{6}$", value.value_from_arn)) > 0
    ])
    error_message = "The value_from_arn must be a valid Secrets Manager ARN with format: arn:aws:secretsmanager:region:account-id:secret:secret-name-suffix"
  }
}

variable "parameters" {
  type = map(
    object({
      data_type      = optional(string, "text")
      description    = optional(string)
      sensitive      = optional(bool, false)
      tier           = optional(string, "Advanced")
      value          = optional(string)
      value_from_arn = optional(string)
    })
  )
  description = "Map of parameters for the Datadog containers, each key will be the name. When the value is set, a parameter is created. Otherwise the arn of existing parameter is added to the outputs."
  default     = {}

  validation {
    condition = alltrue([
      for key, value in var.parameters : (value.value != null) || (value.value_from_arn != null)
    ])
    error_message = "Either value or value_from_arn must be set for each parameter"
  }

  validation {
    condition = alltrue([
      for key, value in var.parameters : (value.value != null && value.value_from_arn != null) ? false : true
    ])
    error_message = "value and value_from_arn cannot be set at the same time for a parameter"
  }

  validation {
    condition = alltrue([
      for key, value in var.parameters :
      value.value_from_arn == null ? true :
      length(regexall("^arn:aws:ssm:[a-zA-Z0-9-]+:[0-9]{12}:parameter/[a-zA-Z0-9-_/]+$", value.value_from_arn)) > 0
    ])
    error_message = "The value_from_arn must be a valid SSM parameter ARN with format: arn:aws:ssm:region:account-id:parameter/parameter-name"
  }

  validation {
    condition = alltrue([
      for key, value in var.parameters :
      contains(["text", "aws:ec2:image", "aws:ssm:integration"], value.data_type)
    ])
    error_message = "data_type must be one of: text, aws:ec2:image, aws:ssm:integration"
  }

  validation {
    condition = alltrue([
      for key, value in var.parameters :
      contains(["Standard", "Advanced", "Intelligent-Tiering"], value.tier)
    ])
    error_message = "tier must be one of: Standard, Advanced, Intelligent-Tiering"
  }
}

variable "kms_key_id" {
  description = "KMS Key identifier to encrypt Datadog API key secret if a new secret is created. Can be in any of the formats: Key ID, Key ARN, Alias Name, Alias ARN"
  type        = string
  default     = null
}

variable "agent_image" {
  description = "Datadog Agent container image configuration. The repository should be the path without registry or tag (e.g., 'datadog/agent'). When pull_cache_prefix is empty (default), images are pulled directly from their source registries (Docker Hub images are automatically resolved with 'docker.io/' prefix by the container runtime). Set pull_cache_prefix to your ECR pull-through cache rule prefix (e.g., 'docker-hub') when using ECR pull cache. The tag is specified separately in 'agent_image_tag'."
  type = object({
    repository        = optional(string, "datadog/agent")
    pull_cache_prefix = optional(string, "")
  })
  default = {}
}

variable "agent_image_tag" {
  description = "Datadog Agent container image tag"
  type        = string
  default     = "7"
  nullable    = false

  validation {
    condition     = var.agent_image_tag != "latest"
    error_message = "Image tag must not be 'latest'. Use a specific version tag instead."
  }
}

variable "agent_cpu" {
  description = "Datadog Agent container CPU units"
  type        = number
  default     = null
}

variable "agent_memory_limit_mib" {
  description = "Datadog Agent container memory limit in MiB"
  type        = number
  default     = null
}

variable "agent_essential" {
  description = "Whether the Datadog Agent container is essential"
  type        = bool
  default     = false
  nullable    = false
}

variable "agent_readonly_root_filesystem" {
  description = "Datadog Agent container runs with read-only root filesystem enabled"
  type        = bool
  default     = false
  nullable    = false
}

variable "agent_health_check" {
  description = "Datadog Agent health check configuration"
  type = object({
    command      = optional(list(string))
    interval     = optional(number)
    retries      = optional(number)
    start_period = optional(number)
    timeout      = optional(number)
  })
  default = {
    command      = ["CMD-SHELL", "/probe.sh"]
    interval     = 15
    retries      = 3
    start_period = 60
    timeout      = 5
  }
}

variable "site" {
  description = "Datadog Site"
  type        = string
  default     = "datadoghq.com"

  validation {
    condition = contains([
      "datadoghq.com",
      "us3.datadoghq.com",
      "us5.datadoghq.com",
      "datadoghq.eu",
      "ddog-gov.com",
      "ap1.datadoghq.com"
    ], var.site)
    error_message = "Site must be one of: `datadoghq.com` (US1), `us3.datadoghq.com` (US3), `us5.datadoghq.com` (US5), `datadoghq.eu` (EU1), `ddog-gov.com` (US1-FED), `ap1.datadoghq.com` (AP1)"
  }
}

variable "agent_environment" {
  description = "Datadog Agent container environment variables. Highest precedence and overwrites other environment variables defined by the module. For example, `agent_environment = [ { name = 'DD_VAR', value = 'DD_VAL' } ]`"
  type        = list(map(string))
  default     = [{}]
  nullable    = false
}

variable "agent_docker_labels" {
  description = "Datadog Agent container docker labels"
  type        = map(string)
  default     = {}
}

variable "agent_tags" {
  description = "Datadog Agent global tags (eg. `key1:value1, key2:value2`)"
  type        = string
  default     = null
}

variable "agent_cluster_name" {
  description = "Override for the Datadog cluster name tag. When not set, the cluster name is automatically detected from ECS metadata API. Only set this if you want to use a different name in Datadog than the actual ECS cluster name."
  type        = string
  default     = null
}

variable "service_name" {
  description = "The service name for Datadog Unified Service Tagging (UST). Sets the `DD_SERVICE` environment variable and `com.datadoghq.tags.service` Docker label. Should identify the service across all environments (e.g., 'web-api', 'payment-service')."
  type        = string
}

variable "stage" {
  description = "The environment/stage name for Datadog Unified Service Tagging (UST). Sets the `DD_ENV` environment variable and `com.datadoghq.tags.env` Docker label. Should identify the deployment environment (e.g., 'production', 'staging', 'dev')."
  type        = string
  default     = null
}

variable "service_version" {
  description = "The version identifier for Datadog Unified Service Tagging (UST). Sets the `DD_VERSION` environment variable and `com.datadoghq.tags.version` Docker label. Should identify the application version (e.g., 'v1.2.3', git commit SHA)."
  type        = string
}

variable "dogstatsd" {
  description = "Configuration for Datadog DogStatsD"
  type = object({
    enabled                  = optional(bool, true)
    origin_detection_enabled = optional(bool, true)
    dogstatsd_cardinality    = optional(string, "orchestrator")
    socket_enabled           = optional(bool, true)
  })
  default = {
    enabled                  = true
    origin_detection_enabled = true
    dogstatsd_cardinality    = "orchestrator"
    socket_enabled           = true
  }
  validation {
    condition     = var.dogstatsd != null
    error_message = "The Datadog Dogstatsd configuration must be defined."
  }
  validation {
    condition     = try(var.dogstatsd.dogstatsd_cardinality == null, false) || can(contains(["low", "orchestrator", "high"], var.dogstatsd.dogstatsd_cardinality))
    error_message = "The Datadog Dogstatsd cardinality must be one of 'low', 'orchestrator', 'high', or null."
  }
}

variable "apm" {
  description = "Configuration for Datadog APM"
  type = object({
    enabled                       = optional(bool, true)
    socket_enabled                = optional(bool, true)
    profiling                     = optional(bool, false)
    trace_inferred_proxy_services = optional(bool, false)
  })
  default = {
    enabled                       = true
    socket_enabled                = true
    profiling                     = false
    trace_inferred_proxy_services = false
  }
  validation {
    condition     = var.apm != null
    error_message = "The Datadog APM configuration must be defined."
  }
}

variable "log_router_image" {
  description = "Fluent Bit log router container image configuration. The repository should be the full image path including registry when pull_cache_prefix is empty, or just the repository path when using ECR pull-through cache. Default uses Amazon ECR Public. Examples: 'public.ecr.aws/aws-observability/aws-for-fluent-bit' (ECR Public, no cache), 'amazon/aws-for-fluent-bit' (Docker Hub, no cache), 'aws-observability/aws-for-fluent-bit' (with pull_cache_prefix='ecr-public'). The tag is specified separately in 'log_router_image_tag'."
  type = object({
    repository        = optional(string, "public.ecr.aws/aws-observability/aws-for-fluent-bit")
    pull_cache_prefix = optional(string, "")
  })
  default = {}
}

variable "log_router_image_tag" {
  description = "Fluent Bit log router container image tag. Version 3.x+ supports YAML configuration files, version 2.x only supports classic .conf format. Use specific version tags (e.g., '3.2.0', '2.34.2') instead of mutable tags like 'stable' or '3' for production deployments."
  type        = string
  default     = "3.2.0"
  nullable    = false

  validation {
    condition     = var.log_router_image_tag != "latest"
    error_message = "Image tag must not be 'latest'. Use a specific version tag instead (e.g., '3.2.0' for YAML support, '2.34.2' for classic config only)."
  }
}

variable "log_collection" {
  description = "Configuration for Datadog Log Collection"
  type = object({
    enabled = optional(bool, false)
    fluentbit_config = optional(object({
      cpu                              = optional(number)
      memory_limit_mib                 = optional(number)
      is_log_router_essential          = optional(bool, false)
      is_log_router_dependency_enabled = optional(bool, false)
      environment = optional(list(object({
        name  = string
        value = string
      })), [])
      log_router_health_check = optional(object({
        command      = optional(list(string))
        interval     = optional(number)
        retries      = optional(number)
        start_period = optional(number)
        timeout      = optional(number)
        }),
        {
          command      = ["CMD-SHELL", "exit 0"]
          interval     = 5
          retries      = 3
          start_period = 15
          timeout      = 5
        }
      )
      firelens_options = optional(object({
        config_file_type  = optional(string)
        config_file_value = optional(string)
      }))
      log_driver_configuration = optional(object({
        host_endpoint = optional(string)
        tls           = optional(bool)
        compress      = optional(string)
        service_name  = optional(string)
        source_name   = optional(string)
        message_key   = optional(string)
        }),
        {}
      )
      log_router_log_configuration = optional(object({
        logDriver = optional(string, "awslogs")
        options   = optional(map(string), {})
        secretOptions = optional(list(object({
          name      = string
          valueFrom = string
        })), [])
        }),
        {
          logDriver = "awslogs"
          options   = {}
        }
      )
      mountPoints = optional(list(object({
        sourceVolume : string,
        containerPath : string,
        readOnly : bool
      })), [])
      dependsOn = optional(list(object({
        containerName : string,
        condition : string
      })), [])
      }),
      {}
    )
  })
  default = {
    enabled = false
    fluentbit_config = {
      is_log_router_essential  = false
      log_driver_configuration = {}
    }
  }
  validation {
    condition     = var.log_collection != null
    error_message = "The Datadog Log Collection configuration must be defined."
  }
  validation {
    condition     = try(var.log_collection.enabled == false, false) || try(var.log_collection.enabled == true && var.log_collection.fluentbit_config != null, false)
    error_message = "The Datadog Log Collection fluentbit configuration must be defined."
  }

}

variable "s3_config_bucket" {
  description = "S3 bucket configuration for storing FluentBit custom configuration files. The bucket is used to host custom parser and filter configurations that are loaded by the FluentBit init process. If the bucket uses KMS encryption, provide the KMS key ID/ARN for decrypt permissions."
  type = object({
    name       = string
    kms_key_id = optional(string)
  })
  default = null
}

variable "log_config_file_format" {
  description = "Datadog log collection configuration file format when using S3 config bucket. Valid values are 'yaml' or 'conf'. Note: YAML format requires Fluent Bit version 3.x or higher (controlled by log_router_image_tag). Version 2.x only supports 'conf' format."
  type        = string
  default     = "yaml"

  validation {
    condition     = contains(["yaml", "conf"], lower(var.log_config_file_format))
    error_message = "log_config_file_format must be either 'yaml' or 'conf'. Note: YAML requires Fluent Bit v3.x+, use 'conf' for v2.x."
  }
}

variable "log_config_parsers" {
  description = "Custom parser definitions for Fluent Bit log processing. Each parser can extract and transform log data using formats like json, regex, ltsv, or logfmt. The optional filter section controls when and how the parser is applied to log records. Required for Fluent Bit v3.x YAML configurations. See: https://docs.fluentbit.io/manual/data-pipeline/parsers/configuring-parser and https://docs.fluentbit.io/manual/pipeline/filters/parser"
  type = list(object({
    name   = string
    format = string
    # JSON parser options
    time_key    = optional(string)
    time_format = optional(string)
    time_keep   = optional(bool)
    # Regex parser options
    regex = optional(string)
    # LTSV parser options (tab-separated values)
    # Logfmt parser options
    # Decoder options
    decode_field    = optional(string)
    decode_field_as = optional(string)
    # Type casting
    types = optional(string)
    # Additional options
    skip_empty_values = optional(bool)
    # Filter configuration - controls when and how this parser is applied
    filter = optional(object({
      match        = optional(string)      # Tag pattern to match (e.g., 'docker.*', 'app.logs')
      key_name     = optional(string)      # Field name to parse (e.g., 'log', 'message')
      reserve_data = optional(bool, false) # Preserve all other fields in the record
      preserve_key = optional(bool, false) # Keep the original key field after parsing
      unescape_key = optional(bool, false) # Unescape the key field before parsing
    }))
  }))
  default = []

  validation {
    condition = alltrue([
      for parser in var.log_config_parsers :
      contains(["json", "regex", "ltsv", "logfmt"], parser.format)
    ])
    error_message = "Parser format must be one of: json, regex, ltsv, logfmt"
  }

  validation {
    condition = alltrue([
      for parser in var.log_config_parsers :
      parser.format != "regex" || parser.regex != null
    ])
    error_message = "Regex parser requires 'regex' field to be set"
  }

  validation {
    condition = alltrue([
      for parser in var.log_config_parsers :
      parser.filter == null || parser.filter.key_name != null
    ])
    error_message = "When filter is specified, 'key_name' is required to identify which field to parse"
  }
}

variable "log_config_filters" {
  description = "Custom filter definitions for Fluent Bit log processing. Filters can modify, enrich, or drop log records. Common filter types include grep (include/exclude), modify (add/rename/remove fields), nest (restructure data), and kubernetes (enrich with K8s metadata). See: https://docs.fluentbit.io/manual/pipeline/filters"
  type = list(object({
    name  = string
    match = optional(string) # Tag pattern to match (e.g., 'docker.*', 'app.logs')
    # Parser filter options
    parser       = optional(string)      # Parser name to apply
    key_name     = optional(string)      # Field name to parse (required for parser filter)
    reserve_data = optional(bool, false) # Preserve all other fields in the record
    preserve_key = optional(bool, false) # Keep the original key field after parsing
    unescape_key = optional(bool, false) # Unescape the key field before parsing
    # Grep filter options
    regex   = optional(string, null) # Regex pattern to match
    exclude = optional(string, null) # Regex pattern to exclude
    # Modify filter options
    add_fields    = optional(map(string), null)  # Fields to add
    rename_fields = optional(map(string), null)  # Fields to rename (old_name = new_name)
    remove_fields = optional(list(string), null) # Fields to remove
    # Nest filter options
    operation     = optional(string, null)       # nest or lift
    wildcard      = optional(list(string), null) # Wildcard patterns
    nest_under    = optional(string, null)       # Target field for nesting
    nested_under  = optional(string, null)       # Source field for lifting
    remove_prefix = optional(string, null)       # Prefix to remove from keys
    add_prefix    = optional(string, null)       # Prefix to add to keys
  }))
  default = []

  validation {
    condition = alltrue([
      for filter in var.log_config_filters :
      filter.name == "parser" ? filter.key_name != null : true
    ])
    error_message = "Parser filter requires 'key_name' to identify which field to parse"
  }

  validation {
    condition = alltrue([
      for filter in var.log_config_filters :
      filter.name == "parser" ? filter.parser != null : true
    ])
    error_message = "Parser filter requires 'parser' field to specify which parser to use"
  }

  validation {
    condition = alltrue([
      for filter in var.log_config_filters :
      filter.name == "nest" ? filter.operation != null : true
    ])
    error_message = "Nest filter requires 'operation' field (nest or lift)"
  }
}

variable "cws_image" {
  description = "Datadog Cloud Workload Security (CWS) instrumentation container image configuration. The repository should be the path without registry or tag (e.g., 'datadog/cws-instrumentation'). When pull_cache_prefix is empty (default), images are pulled directly from their source registries (Docker Hub images are automatically resolved with 'docker.io/' prefix by the container runtime). Set pull_cache_prefix to your ECR pull-through cache rule prefix (e.g., 'docker-hub') when using ECR pull cache. The tag is specified separately in 'cws_image_tag'."
  type = object({
    repository        = optional(string, "datadog/cws-instrumentation")
    pull_cache_prefix = optional(string, "")
  })
  default = {}
}

variable "cws_image_tag" {
  description = "Datadog Cloud Workload Security (CWS) instrumentation container image tag"
  type        = string
  default     = "7.73.0"
  nullable    = false

  validation {
    condition     = var.cws_image_tag != "latest"
    error_message = "Image tag must not be 'latest'. Use a specific version tag instead."
  }
}

variable "cws" {
  description = "Configuration for Datadog Cloud Workload Security (CWS)"
  type = object({
    enabled          = optional(bool, false)
    cpu              = optional(number)
    memory_limit_mib = optional(number)
  })
  default = {
    enabled = false
  }
  validation {
    condition     = var.cws != null
    error_message = "The Datadog Cloud Workload Security (CWS) configuration must be defined."
  }
}

variable "runtime_platform" {
  description = "Configuration for `runtime_platform` that containers in your task may use"
  type = object({
    cpu_architecture        = optional(string, "X86_64")
    operating_system_family = optional(string, "LINUX")
  })
  default = {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  validation {
    condition = var.runtime_platform.operating_system_family == null || contains(
      ["LINUX", "WINDOWS_SERVER_2019_FULL", "WINDOWS_SERVER_2019_CORE", "WINDOWS_SERVER_2022_FULL", "WINDOWS_SERVER_2022_CORE"],
      var.runtime_platform.operating_system_family
    )
    error_message = "operating_system_family must be one of: LINUX, WINDOWS_SERVER_2019_FULL, WINDOWS_SERVER_2019_CORE, WINDOWS_SERVER_2022_FULL, WINDOWS_SERVER_2022_CORE"
  }

  validation {
    condition     = var.runtime_platform.cpu_architecture == null || contains(["X86_64", "ARM64"], var.runtime_platform.cpu_architecture)
    error_message = "cpu_architecture must be one of: X86_64, ARM64"
  }
}

################################################################################
# IAM Policy Configuration
################################################################################

variable "ecs_cluster_name" {
  description = "ARN of the ECS cluster. When provided, IAM policies will be scoped to this cluster. If not provided, policies will use wildcard resources."
  type        = string
  default     = null
}

variable "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition. When provided, task-specific IAM permissions will be scoped to this task definition. Use with ecs_cluster_arn for granular permissions."
  type        = string
  default     = null
}

################################################################################
# Container Integration Configuration
################################################################################

variable "container_mount_path_prefix" {
  description = "Prefix path for container mount points. Datadog sockets will be mounted at this prefix + 'datadog'."
  type        = string
  default     = "/var/run/"
  nullable    = false
}
