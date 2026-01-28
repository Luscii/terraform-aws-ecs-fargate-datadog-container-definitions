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
  attributes = distinct(concat(var.attributes, ["datadog", var.ecs_cluster_name]))
}

module "path" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context   = module.label.context
  delimiter = "/"
}

# ####################### #
# AWS Account information #
# ####################### #

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ecs_cluster" "this" {
  cluster_name = var.ecs_cluster_name
}

# ############################################## #
# Local values for Datadog container definitions #
# ############################################## #

locals {

  is_linux = var.runtime_platform == null || try(var.runtime_platform.operating_system_family == null, true) || try(var.runtime_platform.operating_system_family == "LINUX", true)

  # Centralized container name constants
  # These names are used consistently across all container definitions and dependencies
  container_name_agent      = "datadog-agent"
  container_name_agent_init = "init-volume"
  container_name_log_router = "datadog-log-router"
  container_name_cws_init   = "cws-instrumentation-init"

  # Extract DD_API_KEY ARN from service_secrets outputs for Fluent Bit configuration
  # The container_definition output is a list of {name, valueFrom} objects
  dd_api_key_secret_arn = local.has_api_key ? one([for secret in module.service_secrets.container_definition : secret.valueFrom if secret.name == "DD_API_KEY"]) : null

  # Container image URL construction
  # Builds full image URLs with ECR pull cache support using pull_cache_rule_urls from ecr-pull-cache.tf
  # When pull_cache_prefix is empty, images are constructed without a registry prefix (e.g., "datadog/agent:7").
  # Container runtimes automatically resolve these as Docker Hub images by implicitly prepending "docker.io/".
  # This follows standard Docker image resolution behavior.
  agent_image_url = (
    var.agent_image.pull_cache_prefix != "" ?
    "${local.pull_cache_rule_urls[var.agent_image.pull_cache_prefix]}${var.agent_image.repository}:${var.agent_image_tag}" :
    "${var.agent_image.repository}:${var.agent_image_tag}"
  )

  log_router_image_url = (
    var.log_router_image.pull_cache_prefix != "" ?
    "${local.pull_cache_rule_urls[var.log_router_image.pull_cache_prefix]}${var.log_router_image.repository}:${local.enable_custom_log_config && local.has_custom_parsers ? "init-" : ""}${var.log_router_image_tag}" :
    "${var.log_router_image.repository}:${local.enable_custom_log_config && local.has_custom_parsers ? "init-" : ""}${var.log_router_image_tag}"
  )

  cws_image_url = (
    var.cws_image.pull_cache_prefix != "" ?
    "${local.pull_cache_rule_urls[var.cws_image.pull_cache_prefix]}${var.cws_image.repository}:${var.cws_image_tag}" :
    "${var.cws_image.repository}:${var.cws_image_tag}"
  )
}
