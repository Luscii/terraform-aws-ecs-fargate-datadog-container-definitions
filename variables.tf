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

variable "kms_key_id" {
  description = "KMS Key identifier to encrypt Datadog API key secret if a new secret is created. Can be in any of the formats: Key ID, Key ARN, Alias Name, Alias ARN"
  type        = string
  default     = null
}

variable "registry" {
  description = "Datadog Agent image registry"
  type        = string
  default     = "public.ecr.aws/datadog/agent"
  nullable    = false
}

variable "image_version" {
  description = "Datadog Agent image version"
  type        = string
  default     = "latest"
  nullable    = false
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

variable "log_collection" {
  description = "Configuration for Datadog Log Collection"
  type = object({
    enabled = optional(bool, false)
    fluentbit_config = optional(object({
      registry                         = optional(string, "public.ecr.aws/aws-observability/aws-for-fluent-bit")
      image_version                    = optional(string, "stable")
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
        host_endpoint = optional(string, "http-intake.logs.datadoghq.com")
        tls           = optional(bool)
        compress      = optional(string)
        service_name  = optional(string)
        source_name   = optional(string)
        message_key   = optional(string)
        }),
        {
          host_endpoint = "http-intake.logs.datadoghq.com"
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
      {
        fluentbit_config = {
          registry      = "public.ecr.aws/aws-observability/aws-for-fluent-bit"
          image_version = "stable"
          log_driver_configuration = {
            host_endpoint = "http-intake.logs.datadoghq.com"
          }
        }
      }
    )
  })
  default = {
    enabled = false
    fluentbit_config = {
      is_log_router_essential = false
      log_driver_configuration = {
        host_endpoint = "http-intake.logs.datadoghq.com"
      }
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
  validation {
    condition     = try(var.log_collection.enabled == false, false) || try(var.log_collection.enabled == true && var.log_collection.fluentbit_config.log_driver_configuration != null, false)
    error_message = "The Datadog Log Collection log driver configuration must be defined."
  }
  validation {
    condition     = try(var.log_collection.enabled == false, false) || try(var.log_collection.enabled == true && var.log_collection.fluentbit_config.log_driver_configuration.host_endpoint != null, false)
    error_message = "The Datadog Log Collection log driver configuration host endpoint must be defined."
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

variable "ecs_cluster_arn" {
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
