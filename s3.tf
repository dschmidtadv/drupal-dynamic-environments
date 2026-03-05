# S3 Bucket for Drupal Files
resource "aws_s3_bucket" "drupal_files" {
  bucket = local.drupal_files_bucket_name

  tags = {
    Name = "${var.project_name}-drupal-files"
  }
}

# Enable versioning for data protection
resource "aws_s3_bucket_versioning" "drupal_files" {
  bucket = aws_s3_bucket.drupal_files.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption with customer-managed KMS key
resource "aws_s3_bucket_server_side_encryption_configuration" "drupal_files" {
  bucket = aws_s3_bucket.drupal_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "drupal_files" {
  bucket = aws_s3_bucket.drupal_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy to manage costs
resource "aws_s3_bucket_lifecycle_configuration" "drupal_files" {
  bucket = aws_s3_bucket.drupal_files.id

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }

  rule {
    id     = "delete-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# CORS configuration for Drupal file uploads
resource "aws_s3_bucket_cors_configuration" "drupal_files" {
  bucket = aws_s3_bucket.drupal_files.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["https://${var.wildcard_domain}"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
