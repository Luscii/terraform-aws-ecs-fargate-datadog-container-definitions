# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2025-present Datadog, Inc.

################################################################################
# IAM Policy Documents
################################################################################

# Task Execution Role Policy - Access to Datadog API Key Secret
# Uses the IAM policy document from the service-secrets module
data "aws_iam_policy_document" "task_execution_role" {
  # Include the policy from service-secrets module if it exists
  source_policy_documents = compact([
    module.dd_api_key_secret.iam_policy_document
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
      # If task_definition_arn is provided, scope to specific task; otherwise scope to cluster
      resources = var.ecs_task_definition_arn != null ? [
        var.ecs_task_definition_arn
        ] : [
        "${var.ecs_cluster_arn}/*"
      ]
    }
  }
}
