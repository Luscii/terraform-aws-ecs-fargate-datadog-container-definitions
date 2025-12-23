# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

################################################################################
# IAM Policy Documents
################################################################################

data "aws_iam_policy_document" "execution_pull_cache" {
  count = length(local.pull_cache_rule_arns) > 0 ? 1 : 0
  statement {
    sid    = "DDECRPullThroughCacheAccess"
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
    resources = [for arn in values(local.pull_cache_rule_arns) : "${arn}/*"]
  }
  statement {
    sid    = "DDECRPullThroughCacheCredentials"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = concat(local.pull_cache_credential_arns)
  }
}

# Task Execution Role Policy
#  - Access to Datadog API Key Secret
#    Uses the IAM policy document from the service-secrets module
#  - Access to ECR Pull Through Cache if any pull cache prefixes are configured
#    Includes permissions to read from the pull cache repositories and access the associated Secrets Manager secrets
data "aws_iam_policy_document" "task_execution_role" {
  # Include the policy from service-secrets module if it exists
  source_policy_documents = compact([
    module.service_secrets.iam_policy_document,
    length(data.aws_iam_policy_document.execution_pull_cache) > 0 ? data.aws_iam_policy_document.execution_pull_cache[0].json : null
  ])
}

# Task Role Policy - ECS Metadata Access for Datadog Agent
data "aws_iam_policy_document" "task_role" {
  # Statement for listing and describing ECS resources
  statement {
    sid    = "DatadogECSMetadataAccess"
    effect = "Allow"
    actions = [
      "ecs:ListClusters",
      "ecs:ListContainerInstances",
      "ecs:DescribeContainerInstances"
    ]
    resources = [data.aws_ecs_cluster.this.arn]
  }

  # Additional statement for describing tasks if cluster ARN is provided
  dynamic "statement" {
    for_each = data.aws_ecs_cluster.this.arn != null ? [1] : []
    content {
      sid    = "DatadogECSTaskDescribe"
      effect = "Allow"
      actions = [
        "ecs:DescribeTasks",
        "ecs:ListTasks"
      ]
      # If task_definition_arn is provided, scope to specific task; otherwise scope to cluster
      resources = var.ecs_task_definition_arn != null ? [
        var.ecs_task_definition_arn
        ] : [
        "${data.aws_ecs_cluster.this.arn}/*"
      ]
    }
  }
}
