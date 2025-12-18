output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.this.arn
}

output "datadog_containers" {
  description = "The Datadog container definitions"
  value       = module.datadog_container_definitions.datadog_containers
}
