# LocalStack Setup Guide

This guide provides comprehensive instructions for setting up and configuring LocalStack for local AWS service development and testing.

## Prerequisites

- Docker and Docker Compose
- Node.js 14+ (for LocalStack)
- Python 3.7+ (for AWS CLI and additional tooling)
- Git
- Make (optional, for convenient build/deploy commands)

## Installation

### 1. Install LocalStack

#### Using Docker (Recommended)

```bash
# Pull the latest LocalStack image
docker pull localstack/localstack

# Or install using pip
pip install localstack

# Or install using npm
npm install -g localstack
```

#### Using Homebrew (macOS)

```bash
brew install localstack/tap/localstack
```

### 2. Install AWS CLI Local

```bash
pip install awscli-local
```

### 3. Configure Environment

```bash
# Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

# Or use LocalStack profile
aws configure --profile localstack
```

## Configuration

### LocalStack Configuration File

Create `docker/localstack/docker-compose.yml`:

```yaml
version: "3.8"

services:
  localstack:
    image: localstack/localstack:latest
    container_name: localstack_main
    ports:
      - "4566-4575:4566-4575"
      - "4510-4559:4510-4559"
      - "8080:8080"
      - "8081:8081"
      - "8082:8082"
    environment:
      - DEBUG=${DEBUG:-0}
      - DATA_DIR=${DATA_DIR:-}
      - PORT_WEB_UI=8081
      - LAMBDA_EXECUTOR=${LAMBDA_EXECUTOR:-}
      - KINESIS_ERROR_PROBABILITY=${KINESIS_ERROR_PROBABILITY:-0}
      - DOCKER_HOST=unix:///var/run/docker.sock
      - HOST_TMP_FOLDER=${TMPDIR:-}
    volumes:
      - "${TMPDIR:-/tmp/localstack}:/tmp/localstack"
      - "/var/run/docker.sock:/var/run/docker.sock"
    networks:
      - localstack-network

networks:
  localstack-network:
    driver: bridge
```

### Environment Variables

Create `docker/localstack/.env`:

```bash
# LocalStack Configuration
DEBUG=1
DATA_DIR=/tmp/localstack
LAMBDA_EXECUTOR=local
KINESIS_ERROR_PROBABILITY=0
PORT_WEB_UI=8081

# Service Ports
LOCALSTACK_SERVICES=s3,lambda,dynamodb,apigateway,iam,route53,cloudwatch,events,stepfunctions,sns,sqs,ssm,secretsmanager,elasticsearch,opensearch,firehose,es

# AWS Configuration
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
AWS_ENDPOINT_URL=http://localhost:4566

# Additional Services
START_WEB=0
START_DYNAMODB=1
START_S3=1
START_LAMBDA=1
START_API_GATEWAY=1
```

## Getting Started

### 1. Start LocalStack

```bash
# Navigate to LocalStack directory
cd docker/localstack

# Start services
docker-compose up -d

# Or run directly
localstack start -d

# With custom configuration
docker-compose -f docker-compose.yml -d
```

### 2. Verify Services

```bash
# Check service status
docker-compose ps

# View logs
docker-compose logs -f localstack

# Access LocalStack web UI
open http://localhost:8081

# Test AWS CLI connectivity
aws --endpoint-url http://localhost:4566 s3 ls
```

## Service Endpoints

### Core AWS Services

| Service         | Port | Endpoint           | Description |
| --------------- | ---- | ------------------ | ----------- |
| API Gateway     | 4567 | REST APIs          |
| CloudFormation  | 4581 | Stack management   |
| CloudWatch      | 4582 | Monitoring & logs  |
| DynamoDB        | 4569 | NoSQL database     |
| ElastiCache     | 4568 | In-memory cache    |
| IAM             | 4564 | Identity & access  |
| Kinesis         | 4568 | Streaming data     |
| Lambda          | 4574 | Serverless compute |
| Redshift        | 4577 | Data warehouse     |
| Route53         | 4561 | DNS service        |
| S3              | 4566 | Object storage     |
| Secrets Manager | 4562 | Secrets storage    |
| SES             | 4560 | Email service      |
| SNS             | 4563 | Pub/sub messaging  |
| SQS             | 4565 | Message queuing    |
| SSM             | 4563 | Parameter store    |
| Step Functions  | 4563 | Workflow service   |

### Additional Services

| Service                | Port | Description         |
| ---------------------- | ---- | ------------------- |
| Kinesis Data Analytics | 4568 | Real-time analytics |
| OpenSearch             | 4571 | Search & analytics  |
| Elasticsearch          | 4571 | Search & analytics  |
| Firehose               | 4567 | Data delivery       |

## Integration with Project

### 1. Configure Terraform

```bash
# Navigate to LocalStack Terraform directory
cd terraform/localstack

# Update providers to use LocalStack
cat > providers.tf << 'EOF'
terraform {
  required_providers {
    localstack = {
      source  = "hashicorp/localstack"
      version = "~> 1.0"
    }
  }
}

provider "localstack" {
  endpoint = "http://localhost:4566"
  access_key = "test"
  secret_key = "test"
  region = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check = true
  skip_requesting_account_id = true
}
EOF

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply configuration
terraform apply
```

### 2. Configure Ansible

```bash
# Navigate to Ansible directory
cd ansible

# Update inventory for LocalStack
cat > inventory/localstack.ini << 'EOF'
[localstack]
localhost ansible_connection=local
ansible_python_interpreter=python3

[localstack:vars]
ansible_user=localstack
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_ssh_extra_args='-o UserKnownHostsFile=/dev/null'
EOF

# Test connectivity
ansible -i inventory/localstack.ini localstack -m ping

# Run playbooks
ansible-playbook -i inventory/localstack.ini playbooks/site.yml
```

## Development Workflow

### 1. Local Development

```bash
# Start LocalStack with development settings
DEBUG=1 LAMBDA_EXECUTOR=local docker-compose up -d

# Deploy your infrastructure
cd terraform/localstack
terraform apply -auto-approve

# Run your application tests
cd ../application
npm run test:local
```

### 2. Testing Services

```bash
# Test S3 functionality
aws --endpoint-url http://localhost:4566 s3 mb test-bucket
aws --endpoint-url http://localhost:4566 s3 cp test-file.txt s3://test-bucket/

# Test Lambda functions
aws --endpoint-url http://localhost:4566 lambda invoke \
  --function-name test-function \
  --payload '{"key": "value"}'

# Test DynamoDB
aws --endpoint-url http://localhost:4566 dynamodb create-table \
  --table-name TestTable \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=S
```

### 3. Monitoring and Debugging

```bash
# View all running services
localstack status

# Check specific service logs
localstack logs service-name

# Access service-specific information
curl http://localhost:4566/health | jq '.services.s3'

# Reset state (if needed)
localstack stop
docker system prune -f
localstack start -d
```

## Common Issues and Solutions

### 1. Port Conflicts

```bash
# Check port usage
lsof -i :4566
netstat -tulpn | grep :4566

# Solution: Change ports in docker-compose.yml
ports:
  - "45666-4575:4566-4575"  # Use different range
```

### 2. Permission Issues

```bash
# Fix Docker socket permissions
sudo usermod -aG docker $USER

# Reset Docker permissions
sudo chown $USER:docker /var/run/docker.sock
```

### 3. Memory/Resource Issues

```bash
# Monitor resource usage
docker stats localstack_main

# Increase Docker memory limits
docker-compose up -d --memory=4g

# Use environment variables
LAMBDA_JAVA_OPTS=-Xmx512m docker-compose up -d
```

### 4. Service Startup Failures

```bash
# Check service health
curl http://localhost:4566/health

# Restart specific service
docker-compose restart localstack

# Full reset
docker-compose down -v
docker-compose up -d
```

## Advanced Configuration

### 1. Custom Services

```yaml
# docker/localstack/docker-compose.yml
services:
  localstack:
    image: localstack/localstack:latest
    environment:
      - SERVICES=s3,lambda,dynamodb,apigateway # Limit enabled services
      - DEBUG=1
      - LOCALSTACK_API_KEY=${LOCALSTACK_API_KEY:-your-api-key}
    volumes:
      - ./custom-data:/docker-entrypoint-initaws.d
      - ./scripts:/opt/code/localstack
```

### 2. Persistence

```yaml
# Enable data persistence
volumes:
  localstack_data:
    driver: local

services:
  localstack:
    volumes:
      - localstack_data:/tmp/localstack
    environment:
      - DATA_DIR=/tmp/localstack
      - PERSISTENCE=1
```

### 3. Network Configuration

```yaml
# Custom network setup
networks:
  localstack-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1
```

## Integration with CI/CD

### GitHub Actions

```yaml
# .github/workflows/localstack-test.yml
name: LocalStack Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Start LocalStack
        run: |
          docker run -d -p 4566-4575:4566-4575 localstack/localstack

      - name: Run Tests
        env:
          AWS_ACCESS_KEY_ID: test
          AWS_SECRET_ACCESS_KEY: test
          AWS_DEFAULT_REGION: us-east-1
          AWS_ENDPOINT_URL: http://localhost:4566
        run: |
          # Run your test suite
          npm run test:local

      - name: Cleanup
        if: always()
        run: |
          docker stop $(docker ps -q)
          docker system prune -f
```

### Terraform Cloud/Local

```hcl
# main.tf
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

variable "use_localstack" {
  description = "Use LocalStack for development"
  type        = bool
  default     = false
}

provider "aws" {
  region = var.aws_region

  dynamic "endpoints" {
    for_each = var.use_localstack ? {
      s3       = "http://localhost:4566"
      lambda   = "http://localhost:4566"
      dynamodb = "http://localhost:4566"
    } : {}
  }
}
```

## Best Practices

### 1. Development Environment

- Use specific LocalStack profiles for different environments
- Implement proper logging and monitoring
- Use environment-specific configurations
- Regularly clean up resources

### 2. Testing Strategy

- Test services individually before integration
- Use deterministic test data
- Implement cleanup procedures
- Validate against real AWS services

### 3. Performance Optimization

- Use appropriate resource limits
- Enable service persistence when needed
- Optimize Lambda cold start times
- Monitor resource usage

### 4. Security Considerations

- Use LocalStack only for development/testing
- Never use production credentials
- Implement proper access controls
- Regularly update LocalStack

## Troubleshooting

### Health Check Commands

```bash
# Overall health
curl http://localhost:4566/health

# Service-specific health
curl http://localhost:4566/health?service=s3
curl http://localhost:4566/health?service=lambda

# Check logs for errors
docker-compose logs localstack | grep -i error
```

### Reset and Recovery

```bash
# Complete reset
docker-compose down -v
docker system prune -f
docker-compose up -d

# Reset specific service
curl -X DELETE http://localhost:4566/health?service=lambda

# Clear all data
rm -rf /tmp/localstack/*
docker-compose restart localstack
```

## Resources

### Documentation

- [LocalStack Official Docs](https://docs.localstack.cloud/)
- [AWS CLI Local Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-local.html)
- [Terraform LocalStack Provider](https://registry.terraform.io/providers/hashicorp/localstack/latest/docs)

### Community Support

- [LocalStack GitHub](https://github.com/localstack/localstack)
- [LocalStack Discourse](https://discuss.localstack.cloud/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/localstack)

## Next Steps

1. Set up LocalStack using this guide
2. Test basic service functionality
3. Integrate with your application
4. Configure CI/CD pipelines
5. Implement monitoring and alerting
6. Plan migration to real AWS services

For additional support or questions, refer to the main project documentation or create an issue in the repository.
