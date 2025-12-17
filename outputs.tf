# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

output "container_definitions" {
  description = "A list of valid container definitions provided as a single valid JSON document. This includes Datadog Agent, Log Router, CWS containers, and modified application containers."
  value       = jsonencode(local.container_definitions_list)
}

output "container_definitions_list" {
  description = "The container definitions as a list of objects (not JSON encoded). Useful for further manipulation or inspection."
  value       = local.container_definitions_list
}
