# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

################################################################################
# IAM Policy Documents
################################################################################

# Task Execution Role Policy - Access to Datadog API Key Secret
data "aws_iam_policy_document" "task_execution_role" {
  # Only include this statement if dd_api_key_secret is provided
  dynamic "statement" {
    for_each = var.dd_api_key_secret != null ? [1] : []
    content {
      sid    = "DatadogGetSecretValue"
      effect = "Allow"
      actions = [
        "secretsmanager:GetSecretValue"
      ]
      resources = [
        var.dd_api_key_secret.arn
      ]
    }
  }
}

# Task Role Policy - ECS Metadata Access for Datadog Agent
data "aws_iam_policy_document" "task_role" {
  # Statement for listing and describing ECS resources
  # Only include if ecs_cluster_arn is provided, otherwise use "*" for resources
  statement {
    sid    = "DatadogECSMetadataAccess"
    effect = "Allow"
    actions = [
      "ecs:ListClusters",
      "ecs:ListContainerInstances",
      "ecs:DescribeContainerInstances"
    ]
    resources = var.ecs_cluster_arn != null ? [
      var.ecs_cluster_arn,
      "${var.ecs_cluster_arn}/*"
    ] : ["*"]
  }

  # Additional statement for describing tasks if cluster ARN is provided
  dynamic "statement" {
    for_each = var.ecs_cluster_arn != null ? [1] : []
    content {
      sid    = "DatadogECSTaskDescribe"
      effect = "Allow"
      actions = [
        "ecs:DescribeTasks",
        "ecs:ListTasks"
      ]
      resources = [
        "${var.ecs_cluster_arn}/*"
      ]
    }
  }
}
