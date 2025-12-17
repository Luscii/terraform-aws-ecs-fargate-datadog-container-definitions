provider "aws" {
  region = var.region
}

################################################################################
# Container Definitions Module
################################################################################

module "datadog_container_definitions" {
  source = "../.."

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
# Application Container Definitions
################################################################################

locals {
  app_containers = [
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
      environment = [
        # Add Datadog environment variables for APM
        {
          name  = "DD_TRACE_AGENT_URL"
          value = "unix:///var/run/datadog/apm.socket"
        },
        {
          name  = "DD_DOGSTATSD_URL"
          value = "unix:///var/run/datadog/dsd.socket"
        },
        {
          name  = "DD_ENV"
          value = var.environment
        },
        {
          name  = "DD_SERVICE"
          value = var.service_name
        },
        {
          name  = "DD_VERSION"
          value = var.app_version
        }
      ]
      mountPoints = [
        # Mount Datadog socket volume
        {
          containerPath = "/var/run/datadog"
          sourceVolume  = "dd-sockets"
          readOnly      = false
        }
      ]
      dependsOn = [
        # Wait for Datadog agent to be healthy
        {
          containerName = "datadog-agent"
          condition     = "HEALTHY"
        }
      ]
      dockerLabels = {
        "com.datadoghq.tags.env"     = var.environment
        "com.datadoghq.tags.service" = var.service_name
        "com.datadoghq.tags.version" = var.app_version
      }
    }
  ]
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
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  # Combine Datadog containers with application containers
  container_definitions = jsonencode(
    concat(
      module.datadog_container_definitions.datadog_containers,
      local.app_containers
    )
  )

  # Add required volumes for Datadog
  volume {
    name = "dd-sockets"
  }
}
