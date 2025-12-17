# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

################################################################################
# Datadog API Key Secret Management
################################################################################
# Uses terraform-aws-service-secrets module to manage the Datadog API key

locals {
  # Determine if any Datadog containers are enabled (agent is always created when module is used)
  datadog_enabled = true

  # Check if API key is provided in any form
  has_dd_api_key = var.dd_api_key != null && (
    var.dd_api_key.value != null || var.dd_api_key.value_from_arn != null
  )
}

# Validation: API key must be provided when Datadog is enabled
resource "null_resource" "validate_api_key" {
  count = local.datadog_enabled && !local.has_dd_api_key ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.has_dd_api_key
      error_message = "Datadog API key must be provided. Set var.dd_api_key with either 'value' (for new secret creation) or 'value_from_arn' (for existing secret)."
    }
  }
}

# Validation: UST variables must be provided when Datadog is enabled
resource "null_resource" "validate_ust_variables" {
  count = local.datadog_enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.dd_service != null
      error_message = "var.dd_service is required when Datadog is enabled. This is used for Unified Service Tagging."
    }

    precondition {
      condition     = var.dd_env != null
      error_message = "var.dd_env is required when Datadog is enabled. This is used for Unified Service Tagging."
    }

    precondition {
      condition     = var.dd_version != null
      error_message = "var.dd_version is required when Datadog is enabled. This is used for Unified Service Tagging."
    }
  }
}

# Use terraform-aws-service-secrets module to manage the Datadog API key secret
module "dd_api_key_secret" {
  source = "github.com/Luscii/terraform-aws-service-secrets"

  context = {
    enabled             = local.has_dd_api_key
    namespace           = null
    tenant              = null
    environment         = var.dd_env
    stage               = null
    name                = "datadog-api-key"
    delimiter           = null
    attributes          = []
    tags                = {}
    additional_tag_map  = {}
    regex_replace_chars = null
    label_order         = []
    id_length_limit     = null
    label_key_case      = null
    label_value_case    = null
    descriptor_formats  = {}
    labels_as_tags      = ["unset"]
  }

  kms_key_id = var.kms_key_id

  secrets = local.has_dd_api_key ? {
    DD_API_KEY = {
      value          = try(var.dd_api_key.value, null)
      value_from_arn = try(var.dd_api_key.value_from_arn, null)
      description    = try(var.dd_api_key.description, "Datadog API Key")
    }
  } : {}

  parameters = {}
}

# Local values for use in container definitions
locals {
  # Get the secret ARN from the module
  dd_api_key_secret_arn = local.has_dd_api_key ? module.dd_api_key_secret.secrets["DD_API_KEY"].arn : null

  # Container definition format for secrets
  dd_api_key_container_secret = local.has_dd_api_key ? [
    {
      name      = "DD_API_KEY"
      valueFrom = local.dd_api_key_secret_arn
    }
  ] : []
}
