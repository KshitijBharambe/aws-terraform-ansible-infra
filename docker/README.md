# Docker LocalStack Setup

This directory contains Docker Compose configuration for running LocalStack locally.

## Quick Start

### Start LocalStack
```bash
docker-compose up -d
```

### Check Status
```bash
docker-compose ps
docker-compose logs -f localstack
```

### Test LocalStack
```bash
# Install awslocal (optional but recommended)
pip install awscli-local

# Test S3
awslocal s3 ls

# Or use AWS CLI with endpoint
aws --endpoint-url=http://localhost:4566 s3 ls
```

### Stop LocalStack
```bash
docker-compose down
```

## Configuration

LocalStack is configured with these services:
- S3, EC2, IAM, CloudWatch, SNS, DynamoDB, and more
- Port: 4566
- Region: us-east-1
- Credentials: test/test

## Troubleshooting

### Port 4566 in use
```bash
lsof -i :4566
docker-compose down
docker-compose up -d
```

### Services not responding
```bash
curl http://localhost:4566/_localstack/health
docker-compose restart
```

## Next Steps

Once LocalStack is running:
1. Navigate to `../terraform/localstack/`
2. Run `terraform init`
3. Run `terraform apply`
