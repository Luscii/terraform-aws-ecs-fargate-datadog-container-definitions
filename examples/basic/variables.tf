variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "my-app"
}

variable "app_image" {
  description = "Application Docker image"
  type        = string
  default     = "nginx:latest"
}

variable "app_version" {
  description = "Application version for tagging"
  type        = string
  default     = "1.0.0"
}

variable "service_name" {
  description = "Service name for tagging"
  type        = string
  default     = "my-service"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "datadog_api_key_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret containing the Datadog API key"
  type        = string
}

variable "datadog_site" {
  description = "Datadog site (datadoghq.com, datadoghq.eu, etc.)"
  type        = string
  default     = "datadoghq.com"
}
