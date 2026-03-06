variable "branch_name" {
  description = "Git branch name for this environment"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.branch_name))
    error_message = "Branch name must contain only alphanumeric characters and hyphens."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "ecs_hosts_security_group_id" {
  description = "Security group ID for ECS hosts"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the Application Load Balancer"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer (for CloudWatch metrics)"
  type        = string
}

variable "alb_listener_arn" {
  description = "ARN of the ALB listener (HTTP or HTTPS)"
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  type        = string
}

variable "aurora_endpoint" {
  description = "Aurora cluster endpoint"
  type        = string
}

variable "aurora_database_name" {
  description = "Aurora database name"
  type        = string
}

variable "aurora_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Aurora credentials"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for Drupal files"
  type        = string
}

variable "domain_suffix" {
  description = "Domain suffix for the branch environment (e.g., review.example.gov)"
  type        = string
  default     = "review.example.gov"
}

variable "drupal_image" {
  description = "Docker image for Drupal"
  type        = string
  default     = "drupal:10-apache"
}

variable "drupal_cpu" {
  description = "CPU units for Drupal container (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "drupal_memory" {
  description = "Memory for Drupal container in MB"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of Drupal tasks"
  type        = number
  default     = 1
}

variable "listener_rule_priority" {
  description = "Priority for the ALB listener rule (lower = higher priority)"
  type        = number
}

variable "cloudwatch_kms_key_arn" {
  description = "ARN of the KMS key for CloudWatch Logs encryption"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
