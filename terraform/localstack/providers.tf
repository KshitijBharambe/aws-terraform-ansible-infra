terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.67.0" # Using older, more stable version
    }
  }
}

provider "aws" {
  region = var.aws_region

  # LocalStack Configuration - test credentials
  access_key = "test"
  secret_key = "test"

  # Skip ALL AWS validation for LocalStack
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  # Force use of LocalStack endpoints
  endpoints {
    s3                   = "http://localhost:4566"
    ec2                  = "http://localhost:4566"
    iam                  = "http://localhost:4566"
    dynamodb             = "http://localhost:4566"
    lambda               = "http://localhost:4566"
    apigateway           = "http://localhost:4566"
    cloudformation       = "http://localhost:4566"
    cloudwatch           = "http://localhost:4566"
    logs                 = "http://localhost:4566"
    sns                  = "http://localhost:4566"
    sqs                  = "http://localhost:4566"
    sts                  = "http://localhost:4566"
    secretsmanager       = "http://localhost:4566"
    kms                  = "http://localhost:4566"
    elasticloadbalancing = "http://localhost:4566"
    autoscaling          = "http://localhost:4566"
    ssm                  = "http://localhost:4566"
  }

  # LocalStack S3 configuration
  s3_use_path_style = true
}
