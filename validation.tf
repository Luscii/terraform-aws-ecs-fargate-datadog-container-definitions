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
check "validate_api_key" {
  assert {
    condition     = var.api_key != null && (var.api_key.value != null || var.api_key.value_from_arn != null)
    error_message = "Datadog API key must be provided. Set var.api_key with either 'value' (for new secret creation) or 'value_from_arn' (for existing secret)."
  }
}

check "validate_custom_log_parsers_s3_bucket" {
  assert {
    condition     = (length(var.log_config_parsers) == 0 && length(var.log_config_filters) == 0) || var.s3_config_bucket_name != null
    error_message = "When log_config_parsers or log_config_filters is configured, s3_config_bucket_name must be set to store the custom FluentBit configuration files."
  }
}

check "validate_custom_log_parsers_init_image" {
  assert {
    condition = (length(var.log_config_parsers) == 0 && length(var.log_config_filters) == 0) || (
      can(regex("^init-", var.log_router_image_tag)) ||
      can(regex("^(stable|latest|[0-9]+\\.[0-9]+\\.?[0-9]*)$", var.log_router_image_tag))
    )
    error_message = "When log_config_parsers or log_config_filters is configured, log_router_image_tag must either be an init-tagged image (e.g., 'init-3.2.0') or a standard version tag that will be automatically prefixed with 'init-' by the module (e.g., '3.2.0' becomes 'init-3.2.0'). The module automatically handles the init prefix for you."
  }
}
