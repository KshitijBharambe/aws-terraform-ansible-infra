# 🚀 Quick Start Guide

Get up and running in 5 minutes!

## Prerequisites

Ensure you have these installed:
- Docker Desktop
- Terraform >= 1.5.0
- AWS CLI

```bash
# Check installations
docker --version
terraform --version
aws --version
```

## Step 1: Navigate to Project

```bash
cd /Users/kshtj/CourseWork/Study/Projects/aws-terraform-ansible-infra
```

## Step 2: Start LocalStack

```bash
cd docker
docker-compose up -d
```

Wait 15-30 seconds for initialization.

## Step 3: Verify LocalStack

```bash
# Check health
curl http://localhost:4566/_localstack/health

# Should see services listed as "available" or "running"
```

## Step 4: Initialize Terraform

```bash
cd ../terraform/localstack
terraform init
```

## Step 5: Deploy Infrastructure

```bash
# Review the plan
terraform plan

# Deploy
terraform apply

# Type 'yes' when prompted
```

## Step 6: Verify Resources

```bash
# View outputs
terraform output

# List S3 buckets
aws --endpoint-url=http://localhost:4566 s3 ls

# Or install awslocal for easier commands:
pip3 install awscli-local
awslocal s3 ls
```

## Step 7: Clean Up

```bash
# Destroy infrastructure
terraform destroy

# Stop LocalStack
cd ../../docker
docker-compose down
```

## Success! 🎉

You've deployed infrastructure to LocalStack!

## Next Steps

1. **Explore the code** - Check `terraform/localstack/main.tf`
2. **Read the full README** - `cat ../README.md`
3. **Modify resources** - Edit `terraform.tfvars`
4. **Learn more** - Check documentation in each directory

## Troubleshooting

### LocalStack won't start
```bash
docker ps
docker-compose logs localstack
```

### Terraform errors
```bash
cd terraform/localstack
rm -rf .terraform
terraform init
```

### Port already in use
```bash
lsof -i :4566
# Kill the process or restart Docker
```

## Resources

- LocalStack Dashboard: http://localhost:4566
- Project README: ../README.md
- Terraform Docs: https://www.terraform.io/docs

---

**Happy Learning! 🚀**
