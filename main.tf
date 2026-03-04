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

# Data source for existing VPC
data "aws_vpc" "existing" {
  id = var.vpc_id != "" ? var.vpc_id : null

  dynamic "filter" {
    for_each = var.vpc_id == "" ? [1] : []
    content {
      name   = "tag:Name"
      values = [var.vpc_tag_name]
    }
  }
}

# Data source for existing private subnets
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  dynamic "filter" {
    for_each = var.private_subnet_tag_filter
    content {
      name   = "tag:${filter.key}"
      values = [filter.value]
    }
  }
}

# Use provided subnet IDs or discovered subnets
locals {
  subnet_ids = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : data.aws_subnets.private.ids

  # Generate unique bucket name
  drupal_files_bucket_name = var.drupal_files_bucket_suffix != "" ? "${var.project_name}-drupal-files-${var.drupal_files_bucket_suffix}" : "${var.project_name}-drupal-files-${data.aws_caller_identity.current.account_id}"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get latest ECS-optimized AMI
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# Reference existing IAM instance profile (provided by Cloud Team)
data "aws_iam_instance_profile" "ecs_host" {
  name = var.ecs_instance_profile_name
}
