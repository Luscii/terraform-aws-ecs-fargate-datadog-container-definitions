# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

################################################################################
# Datadog Log Collection Configuration
################################################################################

locals {
  is_fluentbit_supported = var.log_collection.enabled && local.is_linux

  # Calculate log intake host endpoint based on site if not explicitly provided
  log_intake_host = try(
    var.log_collection.fluentbit_config.log_driver_configuration.host_endpoint,
    "http-intake.logs.${var.site}"
  )

  # Datadog Firelens log configuration
  dd_firelens_log_configuration = local.is_fluentbit_supported ? merge(
    {
      logDriver = "awsfirelens"
      options = merge(
        {
          provider    = "ecs"
          Name        = "datadog"
          Host        = local.log_intake_host
          retry_limit = "2"
        },
        var.log_collection.fluentbit_config.log_driver_configuration.tls == true ? { TLS = "on" } : {},
        var.log_collection.fluentbit_config.log_driver_configuration.service_name != null ? { dd_service = var.log_collection.fluentbit_config.log_driver_configuration.service_name } : {},
        var.log_collection.fluentbit_config.log_driver_configuration.source_name != null ? { dd_source = var.log_collection.fluentbit_config.log_driver_configuration.source_name } : {},
        var.log_collection.fluentbit_config.log_driver_configuration.message_key != null ? { dd_message_key = var.log_collection.fluentbit_config.log_driver_configuration.message_key } : {},
        var.log_collection.fluentbit_config.log_driver_configuration.compress != null ? { compress = var.log_collection.fluentbit_config.log_driver_configuration.compress } : {},
        var.agent_tags != null ? { dd_tags = var.agent_tags } : {}
      )
    },
    local.dd_api_key_secret_arn != null ? {
      secretOptions = [
        {
          name      = "apikey"
          valueFrom = local.dd_api_key_secret_arn
        }
      ]
    } : {}
  ) : null

  log_router_dependency = try(var.log_collection.fluentbit_config.is_log_router_dependency_enabled, false) && try(var.log_collection.fluentbit_config.log_router_health_check.command != null, false) && local.dd_firelens_log_configuration != null ? [
    {
      containerName = local.container_name_log_router
      condition     = "HEALTHY"
    }
  ] : []

  dd_log_environment = var.log_collection.fluentbit_config.environment != null ? var.log_collection.fluentbit_config.environment : []

  # Datadog log router container definition
  dd_log_container = local.is_fluentbit_supported ? [
    merge(
      {
        name      = local.container_name_log_router
        image     = local.log_router_image_url
        essential = var.log_collection.fluentbit_config.is_log_router_essential
        firelensConfiguration = {
          type = "fluentbit"
          options = merge(
            {
              enable-ecs-log-metadata = "true"
            },
            try(var.log_collection.fluentbit_config.firelens_options.config_file_type != null, false) ? { config-file-type = var.log_collection.fluentbit_config.firelens_options.config_file_type } : {},
            try(var.log_collection.fluentbit_config.firelens_options.config_file_value != null, false) ? { config-file-value = var.log_collection.fluentbit_config.firelens_options.config_file_value } : {}
          )
        }
        cpu              = var.log_collection.fluentbit_config.cpu
        memory_limit_mib = var.log_collection.fluentbit_config.memory_limit_mib
        user             = "0"
        mountPoints      = var.log_collection.fluentbit_config.mountPoints
        environment      = local.dd_log_environment
        dockerLabels     = var.agent_docker_labels
        portMappings     = []
        systemControls   = []
        volumesFrom      = []
        dependsOn        = var.log_collection.fluentbit_config.dependsOn
      },
      var.log_collection.fluentbit_config.log_router_health_check.command == null ? {} : {
        healthCheck = {
          command     = var.log_collection.fluentbit_config.log_router_health_check.command
          interval    = var.log_collection.fluentbit_config.log_router_health_check.interval
          timeout     = var.log_collection.fluentbit_config.log_router_health_check.timeout
          retries     = var.log_collection.fluentbit_config.log_router_health_check.retries
          startPeriod = var.log_collection.fluentbit_config.log_router_health_check.start_period
        }
      }
    )
  ] : []
}
