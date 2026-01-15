provider "aws" {
  region = var.region
}

################################################################################
# S3 Bucket for Custom FluentBit Configuration
################################################################################

resource "aws_s3_bucket" "config" {
  bucket = var.config_bucket.name
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

################################################################################
# Container Definitions Module with Custom Logging Configuration
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

  # Enable log collection with custom configuration
  log_collection = {
    enabled = true
    fluentbit_config = {
      cpu                     = 128
      memory_limit_mib        = 256
      is_log_router_essential = true
    }
  }

  # S3 bucket for custom FluentBit configuration files
  s3_config_bucket = {
    name = aws_s3_bucket.config.id
  }

  # Configuration file format (yaml for v3.x, conf for v2.x)
  log_config_file_format = "yaml"

  # Custom parsers for log processing
  log_config_parsers = [
    # JSON parser with automatic field extraction
    {
      name        = "json_parser"
      format      = "json"
      time_key    = "timestamp"
      time_format = "%Y-%m-%dT%H:%M:%S.%L"
      time_keep   = true

      # Apply parser filter to docker logs
      filter = {
        match        = "docker.*"
        key_name     = "log"
        reserve_data = true
      }
    },
    # Regex parser for custom log format
    {
      name   = "custom_format"
      format = "regex"
      regex  = "^(?<time>[^ ]+) (?<level>[^ ]+) (?<message>.*)$"

      # Apply to application logs
      filter = {
        match        = "app.*"
        key_name     = "log"
        reserve_data = true
      }
    }
  ]

  # Custom filters for log enrichment and transformation
  log_config_filters = [
    # Add environment tags to all logs
    {
      name = "modify"
      add_fields = {
        environment = var.environment
        service     = var.service_name
        region      = var.region
      }
    },
    # Exclude health check logs
    {
      name    = "grep"
      match   = "docker.*"
      exclude = "health"
    },
    # Nest Kubernetes metadata
    {
      name          = "nest"
      operation     = "nest"
      wildcard      = ["kubernetes_*"]
      nest_under    = "kubernetes"
      remove_prefix = "kubernetes_"
    }
  ]
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
