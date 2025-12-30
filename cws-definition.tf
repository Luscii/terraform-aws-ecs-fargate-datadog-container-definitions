# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

################################################################################
# Datadog Cloud Workload Security (CWS) Container Definition
################################################################################

locals {
  is_cws_supported = local.is_linux && var.cws.enabled

  cws_mount = local.is_cws_supported ? [
    {
      sourceVolume  = "cws-instrumentation-volume"
      containerPath = "/cws-instrumentation-volume"
      readOnly      = false
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

  # Datadog CWS tracer definition
  dd_cws_container = local.is_cws_supported ? [
    {
      name             = local.container_name_cws_init
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
}
