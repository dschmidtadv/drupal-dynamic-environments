output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.drupal.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.drupal.id
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.drupal.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.branch.arn
}

output "hostname" {
  description = "Full hostname for this branch environment"
  value       = local.hostname
}

output "url" {
  description = "Full URL for this branch environment"
  value       = "https://${local.hostname}"
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.branch.name
}
