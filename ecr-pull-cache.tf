# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

################################################################################
# Container Image Configuration
################################################################################
# This file defines how container images are constructed from repository, tag,
# and optional pull_cache_prefix. The actual ECR pull cache rule lookup and
# URL construction should be handled by the calling module (e.g., terraform-aws-ecs-service).

# Collect unique pull cache prefixes from all container configurations
# These are exported via outputs so the calling module can set up ECR pull cache rules
locals {
  pull_cache_prefixes = toset(distinct(compact([
    var.agent_image.pull_cache_prefix != "" ? var.agent_image.pull_cache_prefix : null,
    var.log_router_image.pull_cache_prefix != "" ? var.log_router_image.pull_cache_prefix : null,
    var.cws_image.pull_cache_prefix != "" ? var.cws_image.pull_cache_prefix : null,
  ])))
}
