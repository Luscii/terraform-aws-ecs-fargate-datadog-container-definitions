terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.9"
    }
  }
}

provider "aws" {
  region = var.region
}

################################################################################
# Container Definitions Module
################################################################################

module "datadog_container_definitions" {
  source = "../.."

  # Your application containers
  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = var.app_image
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
    }
  ])

  # Datadog configuration
  dd_api_key_secret = {
    arn = var.datadog_api_key_secret_arn
  }
  dd_site = var.datadog_site

  # Unified Service Tagging
  dd_service = var.service_name
  dd_env     = var.environment
  dd_version = var.app_version
}

################################################################################
# ECS Task Definition
################################################################################

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.service_name}-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = module.datadog_container_definitions.container_definitions
}

################################################################################
# IAM Roles
################################################################################

resource "aws_iam_role" "execution" {
  name = "${var.service_name}-${var.environment}-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "execution_policy" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow access to Datadog API key secret
resource "aws_iam_role_policy" "execution_secrets" {
  name = "datadog-secrets-access"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.datadog_api_key_secret_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "task" {
  name = "${var.service_name}-${var.environment}-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Datadog agent needs ECS permissions
resource "aws_iam_role_policy" "task_datadog" {
  name = "datadog-ecs-permissions"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:ListClusters",
          "ecs:ListContainerInstances",
          "ecs:DescribeContainerInstances"
        ]
        Resource = ["*"]
      }
    ]
  })
}
