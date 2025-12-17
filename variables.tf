# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

################################################################################
# Datadog ECS Fargate Configuration
################################################################################

variable "dd_api_key" {
  description = "Datadog API Key"
  type        = string
  default     = null
}

variable "dd_api_key_secret" {
  description = "Datadog API Key Secret ARN"
  type = object({
    arn = string
  })
  default = null
  validation {
    condition     = var.dd_api_key_secret == null || try(var.dd_api_key_secret.arn != null, false)
    error_message = "If 'dd_api_key_secret' is set, 'arn' must be a non-null string."
  }
}

variable "dd_registry" {
  description = "Datadog Agent image registry"
  type        = string
  default     = "public.ecr.aws/datadog/agent"
  nullable    = false
}

variable "dd_image_version" {
  description = "Datadog Agent image version"
  type        = string
  default     = "latest"
  nullable    = false
}

variable "dd_cpu" {
  description = "Datadog Agent container CPU units"
  type        = number
  default     = null
}

variable "dd_memory_limit_mib" {
  description = "Datadog Agent container memory limit in MiB"
  type        = number
  default     = null
}

variable "dd_essential" {
  description = "Whether the Datadog Agent container is essential"
  type        = bool
  default     = false
  nullable    = false
}

variable "dd_is_datadog_dependency_enabled" {
  description = "Whether the Datadog Agent container is a dependency for other containers"
  type        = bool
  default     = false
  nullable    = false
}

variable "dd_readonly_root_filesystem" {
  description = "Datadog Agent container runs with read-only root filesystem enabled"
  type        = bool
  default     = false
  nullable    = false
}

variable "dd_health_check" {
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

variable "dd_site" {
  description = "Datadog Site"
  type        = string
  default     = "datadoghq.com"
}

variable "dd_environment" {
  description = "Datadog Agent container environment variables. Highest precedence and overwrites other environment variables defined by the module. For example, `dd_environment = [ { name = 'DD_VAR', value = 'DD_VAL' } ]`"
  type        = list(map(string))
  default     = [{}]
  nullable    = false
}

variable "dd_docker_labels" {
  description = "Datadog Agent container docker labels"
  type        = map(string)
  default     = {}
}

variable "dd_tags" {
  description = "Datadog Agent global tags (eg. `key1:value1, key2:value2`)"
  type        = string
  default     = null
}

variable "dd_cluster_name" {
  description = "Datadog cluster name"
  type        = string
  default     = null
}

variable "dd_service" {
  description = "The task service name. Used for tagging (UST)"
  type        = string
  default     = null
}

variable "dd_env" {
  description = "The task environment name. Used for tagging (UST)"
  type        = string
  default     = null
}

variable "dd_version" {
  description = "The task version name. Used for tagging (UST)"
  type        = string
  default     = null
}

variable "dd_checks_cardinality" {
  description = "Datadog Agent checks cardinality"
  type        = string
  default     = null
  validation {
    condition     = var.dd_checks_cardinality == null || can(contains(["low", "orchestrator", "high"], var.dd_checks_cardinality))
    error_message = "The Datadog Agent checks cardinality must be one of 'low', 'orchestrator', 'high', or null."
  }
}

variable "dd_dogstatsd" {
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
    condition     = var.dd_dogstatsd != null
    error_message = "The Datadog Dogstatsd configuration must be defined."
  }
  validation {
    condition     = try(var.dd_dogstatsd.dogstatsd_cardinality == null, false) || can(contains(["low", "orchestrator", "high"], var.dd_dogstatsd.dogstatsd_cardinality))
    error_message = "The Datadog Dogstatsd cardinality must be one of 'low', 'orchestrator', 'high', or null."
  }
}

variable "dd_apm" {
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
    condition     = var.dd_apm != null
    error_message = "The Datadog APM configuration must be defined."
  }
}

variable "dd_log_collection" {
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
    condition     = var.dd_log_collection != null
    error_message = "The Datadog Log Collection configuration must be defined."
  }
  validation {
    condition     = try(var.dd_log_collection.enabled == false, false) || try(var.dd_log_collection.enabled == true && var.dd_log_collection.fluentbit_config != null, false)
    error_message = "The Datadog Log Collection fluentbit configuration must be defined."
  }
  validation {
    condition     = try(var.dd_log_collection.enabled == false, false) || try(var.dd_log_collection.enabled == true && var.dd_log_collection.fluentbit_config.log_driver_configuration != null, false)
    error_message = "The Datadog Log Collection log driver configuration must be defined."
  }
  validation {
    condition     = try(var.dd_log_collection.enabled == false, false) || try(var.dd_log_collection.enabled == true && var.dd_log_collection.fluentbit_config.log_driver_configuration.host_endpoint != null, false)
    error_message = "The Datadog Log Collection log driver configuration host endpoint must be defined."
  }
}

variable "dd_cws" {
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
    condition     = var.dd_cws != null
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
}

################################################################################
# Container Definitions
################################################################################

variable "container_definitions" {
  description = "A list of valid [container definitions](http://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html). Please note that you should only provide values that are part of the container definition document"
  type        = any
}
