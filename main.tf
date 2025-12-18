# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

# Version and Install Info
locals {
  # Datadog ECS task tags
  version = "1.0.6"

  install_info_tool              = "terraform"
  install_info_tool_version      = "terraform-aws-ecs-datadog"
  install_info_installer_version = local.version
}

################################################################################
# CloudPosse Label Module for Resource Naming
################################################################################

module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context    = var.context
  stage      = var.stage
  attributes = ["dd"]
}

# ############################################## #
# Local values for Datadog container definitions #
# ############################################## #

locals {

  is_linux               = var.runtime_platform == null || try(var.runtime_platform.operating_system_family == null, true) || try(var.runtime_platform.operating_system_family == "LINUX", true)
  is_fluentbit_supported = var.log_collection.enabled && local.is_linux

  # Container image URL construction
  # Builds full image URLs with ECR pull cache support when ecr_registry_url is provided
  agent_image_url = (
    var.ecr_registry_url != null && var.agent_image.pull_cache_prefix != "" ?
    "${var.ecr_registry_url}/${var.agent_image.pull_cache_prefix}/${var.agent_image.repository}:${var.agent_image_tag}" :
    "${var.agent_image.repository}:${var.agent_image_tag}"
  )

  log_router_image_url = (
    var.ecr_registry_url != null && var.log_router_image.pull_cache_prefix != "" ?
    "${var.ecr_registry_url}/${var.log_router_image.pull_cache_prefix}/${var.log_router_image.repository}:${var.log_router_image_tag}" :
    "${var.log_router_image.repository}:${var.log_router_image_tag}"
  )

  cws_image_url = (
    var.ecr_registry_url != null && var.cws_image.pull_cache_prefix != "" ?
    "${var.ecr_registry_url}/${var.cws_image.pull_cache_prefix}/${var.cws_image.repository}:${var.cws_image_tag}" :
    "${var.cws_image.repository}:${var.cws_image_tag}"
  )

  # Datadog Firelens log configuration
  dd_firelens_log_configuration = local.is_fluentbit_supported ? merge(
    {
      logDriver = "awsfirelens"
      options = merge(
        {
          provider    = "ecs"
          Name        = "datadog"
          Host        = var.log_collection.fluentbit_config.log_driver_configuration.host_endpoint
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

  # Application container modifications
  is_apm_socket_mount = var.apm.enabled && var.apm.socket_enabled && local.is_linux
  is_dsd_socket_mount = var.dogstatsd.enabled && var.dogstatsd.socket_enabled && local.is_linux
  is_apm_dsd_volume   = local.is_apm_socket_mount || local.is_dsd_socket_mount

  is_cws_supported = local.is_linux && var.cws.enabled

  cws_mount = local.is_cws_supported ? [
    {
      sourceVolume  = "cws-instrumentation-volume"
      containerPath = "/cws-instrumentation-volume"
      readOnly      = false
    }
  ] : []

  apm_dsd_mount = local.is_apm_dsd_volume ? [
    {
      containerPath = "/var/run/datadog"
      sourceVolume  = "dd-sockets"
      readOnly      = false
    }
  ] : []

  dd_agent_mount = concat(
    local.apm_dsd_mount,
    var.agent_readonly_root_filesystem ? [
      {
        containerPath = "/etc/datadog-agent"
        sourceVolume  = "agent-config"
        readOnly      = false
      },
      {
        containerPath = "/tmp"
        sourceVolume  = "agent-tmp"
        readOnly      = false
      },
      {
        containerPath = "/opt/datadog-agent/run"
        sourceVolume  = "agent-run"
        readOnly      = false
      }
    ] : []
  )

  # Note: Dependency variables for application containers are provided via
  # integration-outputs.tf (container_depends_on output) for users to add to their
  # own containers. This module does not modify application containers directly.

  log_router_dependency = try(var.log_collection.fluentbit_config.is_log_router_dependency_enabled, false) && try(var.log_collection.fluentbit_config.log_router_health_check.command != null, false) && local.dd_firelens_log_configuration != null ? [
    {
      containerName = "datadog-log-router"
      condition     = "HEALTHY"
    }
  ] : []

  # Datadog Agent container environment variables
  base_env = [
    {
      name  = "ECS_FARGATE"
      value = "true"
    },
    {
      name  = "DD_ECS_TASK_COLLECTION_ENABLED"
      value = "true"
    },
    {
      name  = "DD_INSTALL_INFO_TOOL"
      value = local.install_info_tool
    },
    {
      name  = "DD_INSTALL_INFO_TOOL_VERSION"
      value = local.install_info_tool_version
    },
    {
      name  = "DD_INSTALL_INFO_INSTALLER_VERSION"
      value = local.install_info_installer_version
    },
    {
      name  = "DD_LOG_FILE"
      value = "/opt/datadog-agent/run/logs"
    }
  ]

  dynamic_env = [
    for pair in [
      { key = "DD_SITE", value = var.site },
      { key = "DD_DOGSTATSD_TAG_CARDINALITY", value = var.dogstatsd.dogstatsd_cardinality },
      { key = "DD_TAGS", value = var.agent_tags },
      { key = "DD_CLUSTER_NAME", value = var.agent_cluster_name },
    ] : { name = pair.key, value = pair.value } if pair.value != null
  ]

  origin_detection_vars = var.dogstatsd.enabled && var.dogstatsd.origin_detection_enabled ? [
    {
      name  = "DD_DOGSTATSD_ORIGIN_DETECTION"
      value = "true"
    },
    {
      name  = "DD_DOGSTATSD_ORIGIN_DETECTION_CLIENT"
      value = "true"
    }
  ] : []

  cws_vars = local.is_cws_supported ? [
    {
      name  = "DD_RUNTIME_SECURITY_CONFIG_ENABLED"
      value = "true"
    },
    {
      name  = "DD_RUNTIME_SECURITY_CONFIG_EBPFLESS_ENABLED"
      value = "true"
    }
  ] : []

  dd_environment = var.agent_environment != null ? var.agent_environment : []

  dd_agent_env = concat(
    local.base_env,
    local.dynamic_env,
    local.origin_detection_vars,
    local.cws_vars,
    local.dd_environment,
  )

  dd_agent_dependency = concat(
    var.agent_readonly_root_filesystem ? [
      {
        condition     = "SUCCESS"
        containerName = "init-volume"
      }
    ] : [],
    try(var.log_collection.fluentbit_config.is_log_router_dependency_enabled, false) && local.dd_firelens_log_configuration != null ? local.log_router_dependency : [],
  )

  # Datadog Agent container definition
  dd_agent_container = concat(
    var.agent_readonly_root_filesystem ? [
      {
        cpu                    = 0
        memory                 = 128
        name                   = "init-volume"
        image                  = local.agent_image_url
        essential              = false
        readOnlyRootFilesystem = true
        command                = ["/bin/sh", "-c", "cp -vnR /etc/datadog-agent/* /agent-config/ && exit 0"]
        mountPoints = [
          {
            sourceVolume  = "agent-config"
            containerPath = "/agent-config"
            readOnly      = false
          }
        ]
      }
    ] : [],
    [
      merge(
        {
          name         = "datadog-agent"
          image        = local.agent_image_url
          essential    = var.agent_essential
          environment  = local.dd_agent_env
          dockerLabels = var.agent_docker_labels
          cpu          = var.agent_cpu
          memory       = var.agent_memory_limit_mib

          readonlyRootFilesystem = var.agent_readonly_root_filesystem
          secrets                = local.dd_api_key_container_secret
          portMappings = [
            {
              containerPort = 8125
              hostPort      = 8125
              protocol      = "udp"
            },
            {
              containerPort = 8126
              hostPort      = 8126
              protocol      = "tcp"
            }
          ],

          mountPoints      = local.dd_agent_mount,
          logConfiguration = local.dd_firelens_log_configuration,
          dependsOn        = local.dd_agent_dependency
          systemControls   = []
          volumesFrom      = []
        },
        try(var.agent_health_check.command == null, true) ? {} : {
          healthCheck = {
            command     = var.agent_health_check.command
            interval    = var.agent_health_check.interval
            timeout     = var.agent_health_check.timeout
            retries     = var.agent_health_check.retries
            startPeriod = var.agent_health_check.start_period
          }
        }
      )
    ]
  )

  dd_log_environment = var.log_collection.fluentbit_config.environment != null ? var.log_collection.fluentbit_config.environment : []

  # Datadog log router container definition
  dd_log_container = local.is_fluentbit_supported ? [
    merge(
      {
        name      = "datadog-log-router"
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

  # Datadog CWS tracer definition
  dd_cws_container = local.is_cws_supported ? [
    {
      name             = "cws-instrumentation-init"
      image            = local.cws_image_url
      cpu              = var.cws.cpu
      memory_limit_mib = var.cws.memory_limit_mib
      user             = "0"
      essential        = false
      entryPoint       = []
      command          = ["/cws-instrumentation", "setup", "--cws-volume-mount", "/cws-instrumentation-volume"]
      mountPoints      = local.cws_mount
      dockerLabels     = var.agent_docker_labels
      portMappings     = []
      systemControls   = []
      volumesFrom      = []
    }
  ] : []

  # Final container definitions output - only Datadog containers
  datadog_containers = concat(
    local.dd_agent_container,
    local.dd_log_container,
    local.dd_cws_container
  )
}
