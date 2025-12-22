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
