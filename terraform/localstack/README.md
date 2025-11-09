# Terraform LocalStack Configuration

This directory contains Terraform configuration for LocalStack.

## Quick Start

```bash
# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Destroy
terraform destroy
```

## What Gets Created

- S3 bucket (test bucket with versioning)
- Security Group (SSH, HTTP, HTTPS rules)
- IAM Role (EC2 assume role with S3/CloudWatch permissions)
- CloudWatch Log Group (if monitoring enabled)
- SNS Topic (if monitoring enabled)

## Configuration Files

- `providers.tf` - AWS provider with LocalStack endpoints
- `backend.tf` - Local state backend
- `variables.tf` - Input variables
- `terraform.tfvars` - Variable values
- `main.tf` - Infrastructure resources
- `outputs.tf` - Output definitions

## Customization

Edit `terraform.tfvars`:
```hcl
project_name = "my-project"
enable_monitoring = false
instance_count = 4
```

## Validation

```bash
terraform fmt -check
terraform validate
terraform plan
```

## Troubleshooting

**Connection refused:**
- Ensure LocalStack is running: `docker-compose ps`
- Check health: `curl http://localhost:4566/_localstack/health`

**Init fails:**
- Remove `.terraform`: `rm -rf .terraform`
- Run `terraform init` again

## Next Steps

After Phase 1:
1. Create VPC module
2. Add compute resources
3. Implement security module
4. Configure monitoring
