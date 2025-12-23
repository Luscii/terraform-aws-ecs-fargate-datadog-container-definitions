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
  region_name = data.aws_region.current.region

  pull_cache_prefixes = toset(distinct(compact([
    var.agent_image.pull_cache_prefix != "" ? var.agent_image.pull_cache_prefix : null,
    var.log_router_image.pull_cache_prefix != "" ? var.log_router_image.pull_cache_prefix : null,
    var.cws_image.pull_cache_prefix != "" ? var.cws_image.pull_cache_prefix : null,
  ])))
}

data "aws_ecr_pull_through_cache_rule" "this" {
  for_each = local.pull_cache_prefixes

  ecr_repository_prefix = each.value
}

locals {
  pull_cache_rule_urls = { for prefix, rule in data.aws_ecr_pull_through_cache_rule.this :
    prefix => "${data.aws_caller_identity.current.account_id}.dkr.ecr.${local.region_name}.amazonaws.com/${rule.ecr_repository_prefix}${endswith(rule.ecr_repository_prefix, "/") ? "" : "/"}"
  }
  pull_cache_rule_arns = { for prefix, rule in data.aws_ecr_pull_through_cache_rule.this :
    prefix => "arn:aws:ecr:${local.region_name}:${data.aws_caller_identity.current.account_id}:repository/${rule.ecr_repository_prefix}"
  }
}

data "aws_secretsmanager_secret" "pull_through_cache_credentials" {
  for_each = data.aws_ecr_pull_through_cache_rule.this

  arn = each.value.credential_arn
}

locals {
  pull_cache_credential_arns = distinct([for secret in data.aws_secretsmanager_secret.pull_through_cache_credentials : secret.arn])
}
