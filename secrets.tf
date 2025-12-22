# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.


################################################################################
# Datadog API Key Secret Management
################################################################################
# Uses terraform-aws-service-secrets module to manage the Datadog API key

locals {
  # Check if API key is provided in any form
  has_api_key = var.api_key != null && (
    var.api_key.value != null || var.api_key.value_from_arn != null
  )
}

# Use terraform-aws-service-secrets module to manage the Datadog API key secret
module "service_secrets" {
  source = "github.com/Luscii/terraform-aws-service-secrets?ref=1.2.1"

  context = module.label.context

  kms_key_id = var.kms_key_id

  secrets = merge(
    var.secrets,
    local.has_api_key ? {
      DD_API_KEY = {
        value          = try(var.api_key.value, null)
        value_from_arn = try(var.api_key.value_from_arn, null)
        description    = try(var.api_key.description, "Datadog API Key")
      }
    } : {}
  )
  parameters = var.parameters
}
