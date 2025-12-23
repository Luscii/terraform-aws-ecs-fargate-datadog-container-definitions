# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

################################################################################
# Datadog General Configuration and Container Combinations
################################################################################

locals {
  # Application container integration settings
  is_apm_socket_mount = var.apm.enabled && var.apm.socket_enabled && local.is_linux
  is_dsd_socket_mount = var.dogstatsd.enabled && var.dogstatsd.socket_enabled && local.is_linux
  is_apm_dsd_volume   = local.is_apm_socket_mount || local.is_dsd_socket_mount

  apm_dsd_mount = local.is_apm_dsd_volume ? [
    {
      containerPath = "/var/run/datadog"
      sourceVolume  = "dd-sockets"
      readOnly      = false
    }
  ] : []

  # Note: Dependency variables for application containers are provided via
  # integration-outputs.tf (container_depends_on output) for users to add to their
  # own containers. This module does not modify application containers directly.

  # Final container definitions output - combines all Datadog containers
  datadog_containers = concat(
    local.dd_agent_container,
    local.dd_log_container,
    local.dd_cws_container
  )
}
