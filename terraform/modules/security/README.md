# Security Module

This module creates security groups for a three-tier architecture (web, application, database), IAM roles and instance profiles for EC2 instances, and optional KMS keys for encryption.

## Features

- ✅ Three-tier security group architecture (web, app, data)
- ✅ Least privilege security group rules
- ✅ IAM roles and instance profiles for EC2
- ✅ CloudWatch Logs and Metrics permissions
- ✅ Optional S3 access permissions
- ✅ Optional Secrets Manager access
- ✅ Optional Systems Manager Session Manager support
- ✅ Optional KMS encryption keys
- ✅ Configurable SSH access controls
- ✅ Comprehensive resource tagging

## Security Architecture

```
┌──────────────────────────────────────────────────┐
│                   Internet                        │
└──────────────┬───────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────┐
│         Web Tier Security Group                  │
│  Ingress: 80, 443 from 0.0.0.0/0                │
│  Ingress: 22 from allowed_ssh_cidr_blocks        │
│  Egress:  All                                    │
└──────────────┬───────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────┐
│      Application Tier Security Group             │
│  Ingress: 8080, 8443 from Web SG                │
│  Ingress: 22 from allowed_ssh_cidr_blocks        │
│  Egress:  All                                    │
└──────────────┬───────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────┐
│        Database Tier Security Group              │
│  Ingress: 5432 from App SG (PostgreSQL)         │
│  Ingress: 3306 from App SG (MySQL)              │
│  Ingress: 22 from allowed_ssh_cidr_blocks        │
│  Egress:  All                                    │
└──────────────────────────────────────────────────┘
```

## Usage

### Basic Usage

```hcl
module "security" {
  source = "../../modules/security"

  project_name = "myproject"
  environment  = "dev"
  vpc_id       = module.vpc.vpc_id
  
  # SSH configuration
  enable_ssh_access        = true
  allowed_ssh_cidr_blocks  = ["10.0.0.0/8"]  # Restrict to internal network
  
  # IAM permissions
  enable_cloudwatch_access = true
  
  tags = {
    Owner      = "DevOps Team"
    CostCenter = "Engineering"
  }
}
```

### Production Usage with Full Security

```hcl
module "security" {
  source = "../../modules/security"

  project_name = "myproject"
  environment  = "prod"
  vpc_id       = module.vpc.vpc_id
  
  # Restrict SSH to specific IP range
  enable_ssh_access        = true
  allowed_ssh_cidr_blocks  = ["203.0.113.0/24"]  # Office IP range only
  
  # Enable comprehensive IAM permissions
  enable_cloudwatch_access       = true
  enable_s3_access               = true
  s3_bucket_arns                 = [
    "arn:aws:s3:::my-app-backups",
    "arn:aws:s3:::my-app-assets"
  ]
  enable_secrets_manager_access  = true
  secrets_manager_arns           = [
    "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/db/password-abc123"
  ]
  enable_ssm_access             = true
  
  # Enable KMS encryption
  enable_kms                    = true
  kms_deletion_window_in_days   = 30
  
  # Custom web ports
  web_ingress_ports             = [80, 443, 8080]
  app_ingress_ports             = [8000, 8443, 9000]
  
  tags = {
    Owner       = "DevOps Team"
    CostCenter  = "Engineering"
    Compliance  = "SOC2"
  }
}
```

### LocalStack Usage

```hcl
module "security" {
  source = "../../modules/security"

  project_name = "localstack-test"
  environment  = "local"
  vpc_id       = module.vpc.vpc_id
  
  # Permissive for development
  enable_ssh_access        = true
  allowed_ssh_cidr_blocks  = ["0.0.0.0/0"]
  
  # Basic CloudWatch access
  enable_cloudwatch_access = true
  
  # KMS not supported in LocalStack Community
  enable_kms               = false
}
```

### Minimal Cost Configuration

```hcl
module "security" {
  source = "../../modules/security"

  project_name = "myproject"
  environment  = "dev"
  vpc_id       = module.vpc.vpc_id
  
  # Enable only what's needed
  enable_ssh_access        = true
  enable_cloudwatch_access = true
  
  # Disable expensive features
  enable_kms               = false
  enable_ssm_access        = false
  enable_s3_access         = false
  
  tags = {
    Owner = "DevOps Team"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project | `string` | n/a | yes |
| environment | Environment name | `string` | `"dev"` | no |
| vpc_id | VPC ID for security groups | `string` | n/a | yes |
| allowed_ssh_cidr_blocks | CIDR blocks for SSH access | `list(string)` | `["0.0.0.0/0"]` | no |
| web_ingress_ports | Ports for web tier | `list(number)` | `[80, 443]` | no |
| app_ingress_ports | Ports for app tier | `list(number)` | `[8080, 8443]` | no |
| enable_ssh_access | Enable SSH access | `bool` | `true` | no |
| ssh_port | SSH port | `number` | `22` | no |
| enable_cloudwatch_access | Enable CloudWatch permissions | `bool` | `true` | no |
| enable_s3_access | Enable S3 permissions | `bool` | `false` | no |
| s3_bucket_arns | S3 bucket ARNs to access | `list(string)` | `[]` | no |
| enable_secrets_manager_access | Enable Secrets Manager | `bool` | `false` | no |
| secrets_manager_arns | Secret ARNs to access | `list(string)` | `[]` | no |
| enable_ssm_access | Enable Session Manager | `bool` | `false` | no |
| enable_kms | Create KMS keys | `bool` | `false` | no |
| kms_deletion_window_in_days | KMS deletion window | `number` | `30` | no |
| tags | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| web_security_group_id | Web tier security group ID |
| web_security_group_name | Web tier security group name |
| app_security_group_id | App tier security group ID |
| app_security_group_name | App tier security group name |
| data_security_group_id | Database tier security group ID |
| data_security_group_name | Database tier security group name |
| all_security_group_ids | All security group IDs |
| instance_role_name | IAM role name |
| instance_role_arn | IAM role ARN |
| instance_profile_name | Instance profile name |
| instance_profile_arn | Instance profile ARN |
| kms_ebs_key_id | EBS KMS key ID |
| kms_ebs_key_arn | EBS KMS key ARN |
| kms_s3_key_id | S3 KMS key ID |
| kms_s3_key_arn | S3 KMS key ARN |
| ssh_enabled | SSH access status |
| ssh_port | Configured SSH port |
| cloudwatch_access_enabled | CloudWatch access status |
| s3_access_enabled | S3 access status |
| ssm_access_enabled | Session Manager status |
| kms_enabled | KMS encryption status |

## Security Best Practices

### SSH Access
⚠️ **IMPORTANT**: The default `allowed_ssh_cidr_blocks = ["0.0.0.0/0"]` is insecure!

**Recommended configurations:**
- **Production**: Restrict to office IP or VPN: `["203.0.113.0/24"]`
- **Development**: Use bastion host or Session Manager
- **Alternative**: Disable SSH and use Systems Manager Session Manager

### IAM Permissions
The module follows least privilege principles:
- Only grants necessary CloudWatch permissions
- S3 access is opt-in with specific bucket ARNs
- Secrets Manager access requires explicit secret ARNs
- Use Systems Manager Session Manager instead of SSH when possible

### Encryption
- **KMS**: Enable in production for compliance (SOC2, HIPAA, PCI-DSS)
- **Cost**: KMS has minimal cost (~$1/key/month)
- **LocalStack**: KMS not supported in Community edition

### Security Group Rules
- Web tier: Only public-facing ports (80, 443)
- App tier: Only accessible from web tier
- Data tier: Only accessible from app tier
- All tiers: Egress unrestricted (can be locked down further if needed)

## Cost Considerations

- **Security Groups**: Free
- **IAM Roles/Policies**: Free
- **KMS Keys**: ~$1/key/month ($2/month for both EBS and S3 keys)
- **Systems Manager**: Free for Session Manager

**Total module cost**: $0-2/month depending on KMS usage

## Examples

### Complete Three-Tier Application

```hcl
module "vpc" {
  source = "../../modules/vpc"
  # ... vpc configuration
}

module "security" {
  source = "../../modules/security"

  project_name = "webapp"
  environment  = "prod"
  vpc_id       = module.vpc.vpc_id
  
  # Secure SSH
  allowed_ssh_cidr_blocks = ["10.0.0.0/8"]
  
  # Full permissions
  enable_cloudwatch_access      = true
  enable_s3_access              = true
  s3_bucket_arns                = [aws_s3_bucket.app_data.arn]
  enable_secrets_manager_access = true
  secrets_manager_arns          = [aws_secretsmanager_secret.db_password.arn]
  enable_ssm_access             = true
  enable_kms                    = true
}

# Use security groups in compute module
module "compute" {
  source = "../../modules/compute"
  
  security_group_ids = [module.security.web_security_group_id]
  iam_instance_profile = module.security.instance_profile_name
  # ...
}
```

## Notes

- Security groups follow a three-tier architecture pattern
- Default SSH access is permissive - **restrict in production!**
- IAM permissions follow least privilege principle
- KMS encryption is optional but recommended for production
- LocalStack Community doesn't support KMS
- Session Manager provides SSH alternative without opening port 22

## Migration Guide

When moving from LocalStack to AWS:
1. Restrict `allowed_ssh_cidr_blocks` to your IP range
2. Enable KMS encryption: `enable_kms = true`
3. Consider enabling Session Manager: `enable_ssm_access = true`
4. Grant S3 access only to specific buckets
5. Use Secrets Manager for sensitive data
