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
