terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# Local values
locals {
  # Private subnet IDs from created subnets
  private_subnet_ids = aws_subnet.private[*].id

  # Public subnet IDs from created subnets
  public_subnet_ids = aws_subnet.public[*].id

  # Generate unique bucket name
  drupal_files_bucket_name = var.drupal_files_bucket_suffix != "" ? "${var.project_name}-drupal-files-${var.drupal_files_bucket_suffix}" : "${var.project_name}-drupal-files-${data.aws_caller_identity.current.account_id}"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get latest ECS-optimized AMI
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

