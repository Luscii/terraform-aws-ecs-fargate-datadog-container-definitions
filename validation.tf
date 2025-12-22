# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

################################################################################
# Configuration Validation Checks
################################################################################

check "validate_stage" {
  assert {
    condition     = try(var.context.stage != null, false) || var.stage != null
    error_message = "stage needs to be set either via context or stage variable. This is used for Unified Service Tagging."
  }
}

check "validate_ecr_registry_url" {
  assert {
    condition = (
      var.ecr_registry_url != null ||
      (
        var.agent_image.pull_cache_prefix == "" &&
        var.log_router_image.pull_cache_prefix == "" &&
        var.cws_image.pull_cache_prefix == ""
      )
    )
    error_message = "When any image has a pull_cache_prefix set, ecr_registry_url must be provided. Either set ecr_registry_url or remove all pull_cache_prefix values."
  }
}
