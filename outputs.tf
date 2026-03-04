output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = local.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = local.public_subnet_ids
}

output "nat_gateway_ips" {
  description = "Elastic IPs of NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "ecs_hosts_security_group_id" {
  description = "Security group ID for ECS hosts"
  value       = aws_security_group.ecs_hosts.id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer (for CloudWatch metrics)"
  value       = aws_lb.main.arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_listener_http_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "alb_listener_https_arn" {
  description = "ARN of the HTTPS listener (if certificate provided)"
  value       = var.certificate_arn != "" ? aws_lb_listener.https[0].arn : null
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = aws_security_group.alb.id
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

output "aurora_cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "aurora_database_name" {
  description = "Aurora database name"
  value       = aws_rds_cluster.aurora.database_name
}

output "aurora_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Aurora credentials"
  value       = aws_secretsmanager_secret.aurora_master_password.arn
}

output "s3_bucket_name" {
  description = "S3 bucket name for Drupal files"
  value       = aws_s3_bucket.drupal_files.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for Drupal files"
  value       = aws_s3_bucket.drupal_files.arn
}

# Instructions for using the branch-environment module
output "branch_environment_module_usage" {
  description = "Instructions for using the branch-environment module"
  value       = <<-EOT
    To create a new branch environment, use the module like this:

    module "branch_feature_xyz" {
      source = "./modules/branch-environment"

      branch_name                  = "feature-xyz"
      project_name                 = var.project_name
      ecs_cluster_id               = aws_ecs_cluster.main.id
      ecs_cluster_name             = aws_ecs_cluster.main.name
      vpc_id                       = aws_vpc.main.id
      private_subnet_ids           = local.private_subnet_ids
      ecs_hosts_security_group_id  = aws_security_group.ecs_hosts.id
      alb_arn                      = aws_lb.main.arn
      alb_arn_suffix               = aws_lb.main.arn_suffix
      alb_listener_arn             = var.certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
      alb_security_group_id        = aws_security_group.alb.id
      ecs_task_execution_role_arn  = aws_iam_role.ecs_task_execution.arn
      ecs_task_role_arn            = aws_iam_role.ecs_task.arn
      aurora_endpoint              = aws_rds_cluster.aurora.endpoint
      aurora_database_name         = aws_rds_cluster.aurora.database_name
      aurora_secret_arn            = aws_secretsmanager_secret.aurora_master_password.arn
      s3_bucket_name               = aws_s3_bucket.drupal_files.id
      domain_suffix                = "review.example.gov"
      listener_rule_priority       = 100  # Must be unique per branch

      tags = var.tags
    }
  EOT
}
