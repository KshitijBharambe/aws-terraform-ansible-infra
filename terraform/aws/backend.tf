# Terraform AWS Backend Configuration
# Configures S3 backend for state management with DynamoDB locking
# Note: Backend configuration cannot use variables - must be hardcoded or use partial configuration

terraform {
  backend "s3" {
    bucket         = "your-project-terraform-state"  # TODO: Replace with actual bucket name
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
    # Enable versioning for state history
    # Enable server-side encryption
    # Use DynamoDB for state locking
  }
}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.terraform_state_bucket
  
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-terraform-state"
      Environment = var.environment
      Purpose     = "Terraform State Storage"
      ManagedBy   = "Terraform"
    }
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_lock" {
  name           = var.terraform_lock_table
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
  
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-terraform-locks"
      Environment = var.environment
      Purpose     = "Terraform State Locking"
      ManagedBy   = "Terraform"
    }
  )
}

# S3 Bucket Lifecycle Policy for State Cleanup
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    id     = "terraform_state_cleanup"
    status = "Enabled"
    
    # Keep state versions for 30 days
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }
    
    # Delete old versions after 90 days
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    
    # Clean up incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# S3 Bucket Policy for Terraform State Access
resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTerraformStateAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.terraform_state_access_arns
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      }
    ]
  })
}

# S3 Bucket Notification for State Changes (Optional)
resource "aws_s3_bucket_notification" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  # Send notifications to SNS when state files are modified
  # This helps with monitoring and auditing
  depends_on = [aws_sns_topic.terraform_state_notifications]
}

# SNS Topic for State Change Notifications
resource "aws_sns_topic" "terraform_state_notifications" {
  name = "${var.project_name}-terraform-state-notifications"
  
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-terraform-state-notifications"
      Environment = var.environment
      Purpose     = "Terraform State Change Notifications"
      ManagedBy   = "Terraform"
    }
  )
}

# CloudWatch Log Group for Terraform Operations
resource "aws_cloudwatch_log_group" "terraform" {
  name = "/aws/terraform/${var.project_name}"
  
  retention_in_days = var.terraform_log_retention_days
  
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-terraform-logs"
      Environment = var.environment
      Purpose     = "Terraform Operation Logs"
      ManagedBy   = "Terraform"
    }
  )
}
