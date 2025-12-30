# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

################################################################################
# Datadog Agent Container Definition
################################################################################

locals {
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
        containerName = local.container_name_agent_init
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
        name                   = local.container_name_agent_init
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
          name         = local.container_name_agent
          image        = local.agent_image_url
          essential    = var.agent_essential
          environment  = local.dd_agent_env
          dockerLabels = var.agent_docker_labels
          cpu          = var.agent_cpu
          memory       = var.agent_memory_limit_mib

          readonlyRootFilesystem = var.agent_readonly_root_filesystem
          secrets                = module.service_secrets.container_definition
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
}
