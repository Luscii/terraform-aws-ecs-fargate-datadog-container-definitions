provider "aws" {
  region = var.region
}

################################################################################
# Container Definitions Module
################################################################################

module "datadog_container_definitions" {
  source = "../.."

  # Datadog API Key (using existing secret)
  api_key = {
    value_from_arn = var.datadog_api_key_secret_arn
  }
  site = var.datadog_site

  # Unified Service Tagging (required)
  service_name    = var.service_name
  stage           = var.environment
  service_version = var.app_version
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

      # Use module outputs for Datadog integration
      environment      = module.datadog_container_definitions.container_environment_variables
      mountPoints      = module.datadog_container_definitions.container_mount_points
      dependsOn        = module.datadog_container_definitions.container_depends_on
      dockerLabels     = module.datadog_container_definitions.container_docker_labels
      logConfiguration = module.datadog_container_definitions.container_log_configuration
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

  # Add required volumes for Datadog using module output
  dynamic "volume" {
    for_each = module.datadog_container_definitions.task_definition_volumes
    content {
      name = volume.value.name
    }
  }
}
