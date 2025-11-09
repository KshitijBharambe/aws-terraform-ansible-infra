#!/bin/bash

# LocalStack Initialization Script
set -e

echo "=========================================="
echo "LocalStack Initialization Starting..."
echo "=========================================="

# Wait for LocalStack to be fully ready
echo "Waiting for LocalStack services to be ready..."
sleep 5

# Set AWS CLI endpoint and credentials for LocalStack
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
ENDPOINT="http://localhost:4566"

# Create S3 bucket for Terraform state
echo ""
echo "Creating S3 bucket for Terraform state..."
awslocal s3 mb s3://terraform-state-localstack 2>/dev/null || echo "Bucket already exists"
awslocal s3api put-bucket-versioning \
    --bucket terraform-state-localstack \
    --versioning-configuration Status=Enabled 2>/dev/null || true

# Create DynamoDB table for Terraform state locking
echo ""
echo "Creating DynamoDB table for state locking..."
awslocal dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    2>/dev/null || echo "Table already exists"

echo ""
echo "=========================================="
echo "LocalStack Initialization Complete!"
echo "=========================================="
echo ""
echo "LocalStack Endpoint: http://localhost:4566"
echo "AWS Region: us-east-1"
echo "Test with: awslocal s3 ls"
echo "=========================================="
