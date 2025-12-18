# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

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

################################################################################
# Datadog API Key Secret Management
################################################################################
# Uses terraform-aws-service-secrets module to manage the Datadog API key

locals {
  # Determine if any Datadog containers are enabled (agent is always created when module is used)
  datadog_enabled = true

  # Check if API key is provided in any form
  has_api_key = var.api_key != null && (
    var.api_key.value != null || var.api_key.value_from_arn != null
  )
}

# Validation: API key must be provided when Datadog is enabled
check "validate_api_key" {
  assert {
    condition     = !local.datadog_enabled || local.has_api_key
    error_message = "Datadog API key must be provided. Set var.api_key with either 'value' (for new secret creation) or 'value_from_arn' (for existing secret)."
  }
}

# Validation: UST variables must be provided when Datadog is enabled
check "validate_ust_variables" {
  assert {
    condition     = !local.datadog_enabled || var.service_name != null
    error_message = "service_name is required when Datadog is enabled. This is used for Unified Service Tagging."
  }

  assert {
    condition     = !local.datadog_enabled || module.label.stage != null
    error_message = "stage is required when Datadog is enabled. Set it via the `stage` variable or `context.stage`; module.label.stage is the merged result used for Unified Service Tagging."
  }

  assert {
    condition     = !local.datadog_enabled || var.service_version != null
    error_message = "service_version is required when Datadog is enabled. This is used for Unified Service Tagging."
  }
}

# Use terraform-aws-service-secrets module to manage the Datadog API key secret
module "api_key_secret" {
  source = "github.com/Luscii/terraform-aws-service-secrets?ref=1.2.1"

  context = module.label.context

  kms_key_id = var.kms_key_id

  secrets = local.has_api_key ? {
    DD_API_KEY = {
      value          = try(var.api_key.value, null)
      value_from_arn = try(var.api_key.value_from_arn, null)
      description    = try(var.api_key.description, "Datadog API Key")
    }
  } : {}

  parameters = {}
}

# Local values for use in container definitions
locals {
  # Get the secret ARN from the module
  dd_api_key_secret_arn = local.has_api_key ? module.api_key_secret.secrets["DD_API_KEY"].arn : null

  # Container definition format for secrets
  dd_api_key_container_secret = local.has_api_key ? [
    {
      name      = "DD_API_KEY"
      valueFrom = local.dd_api_key_secret_arn
    }
  ] : []
}
