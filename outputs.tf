# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

################################################################################
# Container Definition Outputs
################################################################################

output "datadog_agent_container" {
  description = "The Datadog Agent container definition as a list of objects (includes init-volume container if read-only root filesystem is enabled)"
  value       = local.dd_agent_container
}

output "datadog_log_router_container" {
  description = "The Datadog Log Router (Fluent Bit) container definition as a list of objects (empty list if log collection is disabled)"
  value       = local.dd_log_container
}

output "datadog_cws_container" {
  description = "The Datadog Cloud Workload Security instrumentation container definition as a list of objects (empty list if CWS is disabled)"
  value       = local.dd_cws_container
}

output "datadog_containers" {
  description = "All Datadog-related container definitions as a list of objects. Combine this with your application containers in your task definition."
  value       = local.datadog_containers
}

output "datadog_containers_json" {
  description = "All Datadog-related container definitions as a JSON-encoded string. Use this if you need a pre-encoded JSON string."
  value       = jsonencode(local.datadog_containers)
}

################################################################################
# IAM Policy Outputs
################################################################################

output "task_execution_role_policy_json" {
  description = "IAM policy document JSON for the task execution role. Include this in your task execution role to grant access to Datadog secrets. Returns empty string if no secret is configured."
  value       = local.has_api_key ? data.aws_iam_policy_document.task_execution_role.json : ""
  sensitive   = true
}

output "task_role_policy_json" {
  description = "IAM policy document JSON for the task role. Include this in your task role to grant Datadog agent access to ECS metadata."
  value       = data.aws_iam_policy_document.task_role.json
}

################################################################################
# Context Output
################################################################################

output "context" {
  description = "Context output from CloudPosse label module for passing to nested modules"
  value       = module.label.context
}

################################################################################
# Pull Cache Prefixes
################################################################################
output "pull_cache_prefixes" {
  description = "Set of unique ECR pull cache prefixes used by Datadog containers. Use this to set up ECR pull through cache rules and IAM policies in the calling module."
  value       = local.pull_cache_prefixes
}

output "pull_cache_rule_urls" {
  description = "Map of ECR pull cache rule URLs keyed by pull cache prefix. Use this to configure container image URLs in Datadog container definitions."
  value       = local.pull_cache_rule_urls
}

output "pull_cache_rule_arns" {
  description = "Map of ECR pull cache rule ARNs keyed by pull cache prefix. Use this to configure IAM policies if needed."
  value       = local.pull_cache_rule_arns
}

################################################################################
# Custom Logging Configuration Outputs
################################################################################

output "parsers_config_s3_key" {
  description = "S3 object key for the FluentBit parsers configuration file. Returns null if no custom parsers are configured."
  value       = local.enable_custom_log_config && local.has_custom_parsers ? local.parsers_config_key : null
}

output "filters_config_s3_key" {
  description = "S3 object key for the FluentBit filters configuration file. Returns null if no filters are configured."
  value       = local.enable_custom_log_config && local.has_filters ? local.filters_config_key : null
}

################################################################################
# API Key Secret ARN Output
################################################################################

output "dd_api_key_secret_arn" {
  description = "The ARN of the Secrets Manager secret containing the Datadog API key, if configured."
  value       = local.dd_api_key_secret_arn
}

output "dd_api_key_kms_key_id" {
  description = "The KMS key ID used to encrypt the Datadog API key secret, if configured."
  value       = var.kms_key_id
}
