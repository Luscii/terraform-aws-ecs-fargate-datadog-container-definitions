output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.this.arn
}

output "container_definitions" {
  description = "The container definitions JSON"
  value       = module.datadog_container_definitions.container_definitions
}

output "execution_role_arn" {
  description = "ARN of the task execution role"
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ARN of the task role"
  value       = aws_iam_role.task.arn
}
