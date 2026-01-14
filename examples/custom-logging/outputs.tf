output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Family of the ECS task definition"
  value       = aws_ecs_task_definition.this.family
}

output "task_definition_revision" {
  description = "Revision of the ECS task definition"
  value       = aws_ecs_task_definition.this.revision
}

output "datadog_containers" {
  description = "Datadog container definitions (for inspection)"
  value       = module.datadog_container_definitions.datadog_containers
}

output "config_bucket_name" {
  description = "Name of the S3 bucket containing FluentBit configuration"
  value       = aws_s3_bucket.config.id
}

output "config_bucket_arn" {
  description = "ARN of the S3 bucket containing FluentBit configuration"
  value       = aws_s3_bucket.config.arn
}

output "parsers_config_s3_key" {
  description = "S3 key for the parsers configuration file"
  value       = module.datadog_container_definitions.parsers_config_s3_key
}

output "filters_config_s3_key" {
  description = "S3 key for the filters configuration file"
  value       = module.datadog_container_definitions.filters_config_s3_key
}
