# AWS Configuration
aws_region   = "us-east-1"
project_name = "drupal-dynamic"
environment  = "dev"

# VPC Configuration - Creates new VPC
vpc_cidr = "10.0.0.0/16"
az_count = 3  # Number of availability zones (2-6)

# ECS Configuration
ecs_cluster_name         = "drupal-dynamic-environments"
ecs_instance_type        = "t3.medium"
ecs_asg_min_size         = 1
ecs_asg_max_size         = 10
ecs_asg_desired_capacity = 2
spot_instance_percentage = 50

# Scale-to-zero schedule (cron in UTC)
# Default: 8 PM ET (midnight UTC) to 7 AM ET (11 AM UTC)
scale_to_zero_schedule = "0 0 * * *"  # midnight UTC
scale_up_schedule      = "0 11 * * *" # 11 AM UTC

# Aurora Configuration
aurora_engine_version           = "8.0.mysql_aurora.3.04.0"
aurora_min_capacity             = 0.5
aurora_max_capacity             = 2
aurora_auto_pause               = true
aurora_seconds_until_auto_pause = 300
db_master_username              = "drupaladmin"

# ALB Configuration
alb_name        = "drupal-dynamic-alb"
wildcard_domain = "*.review.example.gov"

# Optional: Provide ACM certificate ARN for HTTPS
# certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# S3 Configuration
# Optional: Provide a suffix for the S3 bucket name
# drupal_files_bucket_suffix = "prod"

# Tags
tags = {
  Project     = "DrupalDynamicEnvironments"
  Environment = "dev"
  ManagedBy   = "Terraform"
  Team        = "Platform"
}
