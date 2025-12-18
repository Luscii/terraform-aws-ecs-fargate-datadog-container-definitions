# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

################################################################################
# Container Integration Helper Outputs
################################################################################
# These outputs simplify integrating Datadog containers into application containers

locals {
  # Calculate the container mount path for Datadog sockets
  datadog_socket_path = "${var.container_mount_path_prefix}datadog"

  # Determine which containers are enabled
  log_router_enabled = var.log_collection.enabled && local.is_fluentbit_supported
  cws_enabled        = var.cws.enabled

  # Build depends_on list based on enabled containers
  datadog_depends_on = concat(
    [
      {
        containerName = "datadog-agent"
        condition     = "HEALTHY"
      }
    ],
    local.log_router_enabled ? [
      {
        containerName = "log_router"
        condition     = "START"
      }
    ] : [],
    local.cws_enabled ? [
      {
        containerName = "cws-instrumentation-init"
        condition     = "SUCCESS"
      }
    ] : []
  )

  # Build environment variables list
  datadog_environment_variables = concat(
    # APM trace agent URL (only if socket is enabled)
    var.apm.enabled && var.apm.socket_enabled ? [
      {
        name  = "DD_TRACE_AGENT_URL"
        value = "unix://${local.datadog_socket_path}/apm.socket"
      }
    ] : [],
    # DogStatsD URL (only if socket is enabled)
    var.dogstatsd.enabled && var.dogstatsd.socket_enabled ? [
      {
        name  = "DD_DOGSTATSD_URL"
        value = "unix://${local.datadog_socket_path}/dsd.socket"
      }
    ] : [],
    # Unified Service Tagging
    module.label.stage != null ? [
      {
        name  = "DD_ENV"
        value = module.label.stage
      }
    ] : [],
    var.service_name != null ? [
      {
        name  = "DD_SERVICE"
        value = var.service_name
      }
    ] : [],
    var.service_version != null ? [
      {
        name  = "DD_VERSION"
        value = var.service_version
      }
    ] : []
  )

  # Build mount points list
  datadog_mount_points = concat(
    # Datadog socket volume (only if APM or DogStatsD sockets are enabled)
    (var.apm.enabled && var.apm.socket_enabled) || (var.dogstatsd.enabled && var.dogstatsd.socket_enabled) ? [
      {
        containerPath = local.datadog_socket_path
        sourceVolume  = "dd-sockets"
        readOnly      = false
      }
    ] : [],
    # CWS instrumentation volume (only if CWS is enabled)
    local.cws_enabled ? [
      {
        containerPath = "/cws-instrumentation-volume"
        sourceVolume  = "cws-instrumentation-volume"
        readOnly      = false
      }
    ] : []
  )

  # Build docker labels map
  datadog_docker_labels = merge(
    module.label.stage != null ? {
      "com.datadoghq.tags.env" = module.label.stage
    } : {},
    var.service_name != null ? {
      "com.datadoghq.tags.service" = var.service_name
    } : {},
    var.service_version != null ? {
      "com.datadoghq.tags.version" = var.service_version
    } : {}
  )
}

output "container_environment_variables" {
  description = "List of environment variables to add to application containers for Datadog integration. Includes DD_TRACE_AGENT_URL, DD_DOGSTATSD_URL (if socket-based), and Unified Service Tagging variables."
  value       = local.datadog_environment_variables
}

output "container_mount_points" {
  description = "List of mount points to add to application containers for Datadog integration. Includes Datadog socket volume and CWS instrumentation volume (if enabled)."
  value       = local.datadog_mount_points
}

output "container_depends_on" {
  description = "List of container dependencies to add to application containers. Ensures Datadog agent (and log router/CWS if enabled) are ready before application starts."
  value       = local.datadog_depends_on
}

output "container_docker_labels" {
  description = "Map of Docker labels to add to application containers for Unified Service Tagging. Includes env, service, and version labels."
  value       = local.datadog_docker_labels
}

output "task_definition_volumes" {
  description = "List of volume definitions to add to the ECS task definition. Includes dd-sockets volume (if APM/DogStatsD sockets enabled) and cws-instrumentation-volume (if CWS is enabled)."
  value = concat(
    # Socket volume (only if APM or DogStatsD sockets are enabled)
    (var.apm.enabled && var.apm.socket_enabled) || (var.dogstatsd.enabled && var.dogstatsd.socket_enabled) ? [
      {
        name = "dd-sockets"
      }
    ] : [],
    # CWS volume (only if CWS is enabled)
    local.cws_enabled ? [
      {
        name = "cws-instrumentation-volume"
      }
    ] : []
  )
}
