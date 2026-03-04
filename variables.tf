variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "drupal-dynamic"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

# VPC Configuration - Create new VPC
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to use (creates public + private subnets in each)"
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 6
    error_message = "AZ count must be between 2 and 6 for high availability."
  }
}

# ECS Configuration
variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "drupal-dynamic-environments"
}

variable "ecs_instance_type" {
  description = "EC2 instance type for ECS hosts"
  type        = string
  default     = "t3.medium"
}

variable "ecs_asg_min_size" {
  description = "Minimum size of the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "ecs_asg_max_size" {
  description = "Maximum size of the Auto Scaling Group"
  type        = number
  default     = 10
}

variable "ecs_asg_desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "spot_instance_percentage" {
  description = "Percentage of Spot instances in the ASG (0-100)"
  type        = number
  default     = 50
}

variable "scale_to_zero_schedule" {
  description = "Cron expression for scale-to-zero (default: 8 PM ET)"
  type        = string
  default     = "0 0 * * *" # midnight UTC (8 PM ET)
}

variable "scale_up_schedule" {
  description = "Cron expression for scale-up (default: 7 AM ET)"
  type        = string
  default     = "0 11 * * *" # 11 AM UTC (7 AM ET)
}

# Aurora Configuration
variable "aurora_engine_version" {
  description = "Aurora MySQL engine version"
  type        = string
  default     = "8.0.mysql_aurora.3.04.0"
}

variable "aurora_min_capacity" {
  description = "Minimum Aurora capacity units"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Maximum Aurora capacity units"
  type        = number
  default     = 2
}

variable "aurora_auto_pause" {
  description = "Enable auto-pause for Aurora Serverless"
  type        = bool
  default     = true
}

variable "aurora_seconds_until_auto_pause" {
  description = "Seconds of inactivity before auto-pause"
  type        = number
  default     = 300
}

variable "db_master_username" {
  description = "Master username for Aurora database"
  type        = string
  default     = "drupaladmin"
  sensitive   = true
}

# ALB Configuration
variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
  default     = "drupal-dynamic-alb"
}

variable "wildcard_domain" {
  description = "Wildcard domain for branch environments (e.g., *.review.example.gov)"
  type        = string
  default     = "*.review.example.gov"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (optional)"
  type        = string
  default     = ""
}

# S3 Configuration
variable "drupal_files_bucket_suffix" {
  description = "Suffix for Drupal files S3 bucket (full name will be {project_name}-drupal-files-{suffix})"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "DrupalDynamicEnvironments"
    ManagedBy = "Terraform"
  }
}
