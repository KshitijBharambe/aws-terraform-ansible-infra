# AWS Provider Configuration for Aliased Providers
# Additional provider configurations for specific services

# AWS Provider for us-east-1 (for global resources)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = var.common_tags
  }

  # Configure retry settings for better reliability
  retry_mode  = "adaptive"
  max_retries = 3

  dynamic "assume_role" {
    for_each = var.assume_role_arn != null ? [1] : []
    content {
      role_arn = var.assume_role_arn
    }
  }
}

# AWS Provider for CloudWatch Logs (us-east-1 required)
provider "aws" {
  alias  = "logs"
  region = "us-east-1"

  default_tags {
    tags = merge(
      var.common_tags,
      {
        Purpose = "CloudWatch Logs"
      }
    )
  }

  dynamic "assume_role" {
    for_each = var.assume_role_arn != null ? [1] : []
    content {
      role_arn = var.assume_role_arn
    }
  }
}

# AWS Provider for Route53 (if using DNS management)
provider "aws" {
  alias  = "route53"
  region = var.aws_region

  default_tags {
    tags = merge(
      var.common_tags,
      {
        Purpose = "DNS Management"
      }
    )
  }

  dynamic "assume_role" {
    for_each = var.assume_role_arn != null ? [1] : []
    content {
      role_arn = var.assume_role_arn
    }
  }
}

# AWS Provider for ACM (if using SSL certificates)
provider "aws" {
  alias  = "acm"
  region = "us-east-1" # ACM for CloudFront must be in us-east-1

  default_tags {
    tags = merge(
      var.common_tags,
      {
        Purpose = "SSL Certificate Management"
      }
    )
  }

  dynamic "assume_role" {
    for_each = var.assume_role_arn != null ? [1] : []
    content {
      role_arn = var.assume_role_arn
    }
  }
}

# Get available AWS regions for multi-region deployments
data "aws_regions" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required", "opted-in"]
  }
}

# Get current AWS account information
data "aws_organizations_organization" "current" {
  count = var.enable_organizations_integration ? 1 : 0
}

# Get VPC information for existing network integration
data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  id    = var.existing_vpc_id
}

# Get existing subnets for integration
data "aws_subnets" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [var.existing_vpc_id]
  }
}

# Provider configuration for cost optimization
locals {
  # Use ARM instances for cost savings (60% less than x86)
  use_arm_instances = var.cost_optimization_enabled

  # Use spot instances for additional savings (up to 90%)
  use_spot_instances = var.cost_optimization_enabled && var.enable_spot_instances

  # Use regional endpoints for cost savings
  use_regional_endpoints = var.cost_optimization_enabled

  # Enable savings plans for predictable workloads
  enable_savings_plans = var.cost_optimization_enabled && var.enable_savings_plans

  # Configure cost allocation tags for better cost tracking
  cost_allocation_tags = concat(
    var.cost_tracking_tags,
    [
      "Project",
      "Environment",
      "Owner",
      "ManagedBy"
    ]
  )
}
