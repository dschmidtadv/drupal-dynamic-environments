# Example: Creating branch environments
#
# This file demonstrates how to use the branch-environment module
# to create dynamic Drupal environments for different Git branches.
#
# In practice, you would:
# 1. Have a CI/CD pipeline (AWS CodeBuild) that passes branch_name as a variable
# 2. Use Terraform workspaces or dynamic module instantiation
# 3. Or generate these module blocks programmatically

# Example: UAT environment (long-lasting)
module "branch_uat" {
  source = "./modules/branch-environment"

  branch_name                 = "uat"
  project_name                = var.project_name
  ecs_cluster_id              = aws_ecs_cluster.main.id
  ecs_cluster_name            = aws_ecs_cluster.main.name
  vpc_id                      = aws_vpc.main.id
  private_subnet_ids          = local.private_subnet_ids
  ecs_hosts_security_group_id = aws_security_group.ecs_hosts.id
  alb_arn                     = aws_lb.main.arn
  alb_listener_arn            = var.certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  alb_security_group_id       = aws_security_group.alb.id
  ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution.arn
  ecs_task_role_arn           = aws_iam_role.ecs_task.arn
  aurora_endpoint             = aws_rds_cluster.aurora.endpoint
  aurora_database_name        = aws_rds_cluster.aurora.database_name
  aurora_secret_arn           = aws_secretsmanager_secret.aurora_master_password.arn
  s3_bucket_name              = aws_s3_bucket.drupal_files.id
  domain_suffix               = "review.example.gov"

  # Configuration
  drupal_image   = "drupal:10-apache"
  drupal_cpu     = 512
  drupal_memory  = 1024
  desired_count  = 2 # UAT should have at least 2 instances

  listener_rule_priority = 10 # Lower priority = higher precedence

  tags = merge(
    var.tags,
    {
      Environment = "UAT"
      Lifecycle   = "long-lasting"
    }
  )
}

# Example: Feature branch environment (ephemeral)
module "branch_feature_auth" {
  source = "./modules/branch-environment"

  branch_name                 = "feature-auth"
  project_name                = var.project_name
  ecs_cluster_id              = aws_ecs_cluster.main.id
  ecs_cluster_name            = aws_ecs_cluster.main.name
  vpc_id                      = aws_vpc.main.id
  private_subnet_ids          = local.private_subnet_ids
  ecs_hosts_security_group_id = aws_security_group.ecs_hosts.id
  alb_arn                     = aws_lb.main.arn
  alb_listener_arn            = var.certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  alb_security_group_id       = aws_security_group.alb.id
  ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution.arn
  ecs_task_role_arn           = aws_iam_role.ecs_task.arn
  aurora_endpoint             = aws_rds_cluster.aurora.endpoint
  aurora_database_name        = aws_rds_cluster.aurora.database_name
  aurora_secret_arn           = aws_secretsmanager_secret.aurora_master_password.arn
  s3_bucket_name              = aws_s3_bucket.drupal_files.id
  domain_suffix               = "review.example.gov"

  # Configuration
  drupal_image   = "drupal:10-apache"
  drupal_cpu     = 512
  drupal_memory  = 1024
  desired_count  = 1 # Feature branches can start with 1 instance

  listener_rule_priority = 100 # Each branch needs a unique priority

  tags = merge(
    var.tags,
    {
      Environment = "Feature"
      Lifecycle   = "ephemeral"
    }
  )
}

# Outputs for branch environments
output "uat_url" {
  description = "URL for UAT environment"
  value       = module.branch_uat.url
}

output "feature_auth_url" {
  description = "URL for feature-auth environment"
  value       = module.branch_feature_auth.url
}

# Note: In a CI/CD pipeline, you would dynamically create these module blocks
# based on the branch_name variable. Here's how you might structure it:
#
# 1. CI/CD Pipeline passes: -var="branch_name=feature-xyz"
# 2. Use terraform workspace or dynamic configuration
# 3. Generate unique listener_rule_priority (e.g., hash of branch name % 1000)
