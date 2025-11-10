# Deployment Runbook

## Overview

This runbook provides step-by-step procedures for deploying the AWS-Terraform-Ansible infrastructure project. It covers initial setup, full deployments, updates, and troubleshooting scenarios.

## Prerequisites

### Required Tools

- **Terraform** >= 1.5.0
- **Ansible** >= 2.14.0
- **AWS CLI** >= 2.0
- **Git** for version control
- **Docker** (for local testing)

### AWS Permissions

Ensure your AWS credentials have sufficient permissions:

- IAM role with `AdministratorAccess` (for initial setup)
- Subsequent deployments use least-privilege roles
- MFA enabled on AWS account

### Environment Setup

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Verify tool versions
terraform --version
ansible --version
aws --version
```

## Quick Deployment

### 1. Clone Repository

```bash
git clone https://github.com/KshitijBharambe/aws-terraform-ansible-infra.git
cd aws-terraform-ansible-infra
```

### 2. Configure Environment

```bash
# Copy and edit variables
cp terraform/aws/terraform.tfvars.example terraform/aws/terraform.tfvars
cp ansible/inventory/group_vars/all.yml.example ansible/inventory/group_vars/all.yml

# Edit configuration files
vim terraform/aws/terraform.tfvars
vim ansible/inventory/group_vars/all.yml
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
make init

# Plan deployment
make plan

# Apply changes
make deploy
```

### 4. Configure Application Layer

```bash
# Update Ansible inventory
make inventory

# Run Ansible playbooks
make provision
```

## Detailed Deployment Process

### Phase 1: Environment Preparation

#### 1.1 Backend Configuration

```bash
# Navigate to AWS Terraform directory
cd terraform/aws

# Initialize Terraform backend
terraform init \
  -backend-config="bucket=your-terraform-state-bucket" \
  -backend-config="key=infrastructure.tfstate" \
  -backend-config="region=us-east-1"

# Verify backend configuration
terraform validate
```

#### 1.2 Provider Configuration

Verify `providers.tf` contains required providers:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "aws-terraform-ansible-infra"
      ManagedBy   = "terraform"
    }
  }
}
```

### Phase 2: Infrastructure Deployment

#### 2.1 Network Layer Deployment

```bash
# Deploy VPC and networking components first
terraform apply -target=module.vpc

# Verify VPC creation
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=main-vpc"
```

#### 2.2 Security Layer Deployment

```bash
# Deploy security groups and IAM roles
terraform apply -target=module.security

# Verify security groups
aws ec2 describe-security-groups --filters "Name=tag:Environment,Values=${ENVIRONMENT}"
```

#### 2.3 Compute Layer Deployment

```bash
# Deploy EC2 instances and load balancers
terraform apply -target=module.compute
terraform apply -target=module.loadbalancer

# Verify instance health
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"
```

#### 2.4 Monitoring Setup

```bash
# Deploy monitoring and logging
terraform apply -target=module.monitoring

# Verify CloudTrail setup
aws cloudtrail describe-trails
```

#### 2.5 Full Infrastructure Deployment

```bash
# Deploy all remaining components
terraform apply
```

### Phase 3: Application Configuration

#### 3.1 Ansible Inventory Setup

```bash
# Generate dynamic inventory
cd ../../ansible
ansible-inventory -i inventory/aws_ec2.yml --list

# Verify connectivity
ansible -i inventory/aws_ec2.yml all -m ping
```

#### 3.2 Common Configuration

```bash
# Apply common system configuration
ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml --tags common

# Verify system updates
ansible -i inventory/aws_ec2.yml all -m command -a "cat /etc/os-release"
```

#### 3.3 Security Hardening

```bash
# Apply security hardening
ansible-playbook -i inventory/aws_ec2.yml playbooks/hardening.yml

# Verify SSH hardening
ansible -i inventory/aws_ec2.yml webservers -m command -a "grep PermitRootLogin /etc/ssh/sshd_config"
```

#### 3.4 Web Server Configuration

```bash
# Configure web servers
ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml --tags webserver

# Verify web server status
ansible -i inventory/aws_ec2.yml webservers -m command -a "systemctl status nginx"
```

#### 3.5 Monitoring Setup

```bash
# Configure monitoring
ansible-playbook -i inventory/aws_ec2.yml playbooks/monitoring.yml

# Verify monitoring agents
ansible -i inventory/aws_ec2.yml all -m command -a "systemctl status cloudwatch-agent"
```

## Environment-Specific Deployments

### Development Environment

```bash
# Set environment
export TF_VAR_environment=dev
export ENVIRONMENT=dev

# Deploy with smaller instance types
cat > terraform/aws/terraform.tfvars << EOF
environment = "dev"
aws_region   = "us-east-1"
instance_type = "t3.micro"
key_pair_name = "dev-key"
enable_monitoring = false
backup_retention_days = 7
EOF

# Deploy
terraform apply
```

### Staging Environment

```bash
# Set environment
export TF_VAR_environment=staging
export ENVIRONMENT=staging

# Deploy with medium resources
cat > terraform/aws/terraform.tfvars << EOF
environment = "staging"
aws_region   = "us-east-1"
instance_type = "t3.small"
key_pair_name = "staging-key"
enable_monitoring = true
backup_retention_days = 14
EOF

# Deploy
terraform apply
```

### Production Environment

```bash
# Set environment
export TF_VAR_environment=prod
export ENVIRONMENT=prod

# Deploy with production resources
cat > terraform/aws/terraform.tfvars << EOF
environment = "prod"
aws_region   = "us-east-1"
instance_type = "t3.medium"
key_pair_name = "prod-key"
enable_monitoring = true
backup_retention_days = 30
enable_encryption = true
multi_az = true
EOF

# Deploy with extra confirmation
terraform apply -auto-approve=false
```

## Blue-Green Deployment

### Phase 1: Green Environment Setup

```bash
# Create green environment
export TF_VAR_environment=green
export TF_VAR_vpc_cidr="10.1.0.0/16"

# Deploy green infrastructure
terraform apply -var-file=green.tfvars
```

### Phase 2: Application Deployment to Green

```bash
# Update Ansible inventory for green
ansible-playbook -i inventory/green.yml playbooks/site.yml

# Test green environment
curl -k https://green-loadbalancer.example.com/health
```

### Phase 3: Traffic Switch

```bash
# Update DNS to point to green
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1ABC123DEF456 \
  --change-batch file://dns-swap.json
```

### Phase 4: Blue Environment Cleanup

```bash
# After verification, cleanup blue environment
export TF_VAR_environment=blue
terraform destroy -auto-approve
```

## Rolling Updates

### Application Updates

```bash
# Update application code
git pull origin main

# Update web servers in batches
ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml \
  --tags webserver \
  --limit webservers[0:2]  # First batch

# Verify first batch
ansible -i inventory/aws_ec2.yml webservers[0:2] -m uri \
  -a "url=http://localhost/health"

# Continue with remaining batches
ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml \
  --tags webserver \
  --limit webservers[2:]  # Remaining servers
```

### System Updates

```bash
# Apply security updates in batches
ansible-playbook -i inventory/aws_ec2.yml playbooks/update.yml \
  --limit webservers[0:3]

# Reboot batch
ansible -i inventory/aws_ec2.yml webservers[0:3] -m reboot

# Continue with next batch
ansible-playbook -i inventory/aws_ec2.yml playbooks/update.yml \
  --limit webservers[3:6]
```

## Troubleshooting Deployment Issues

### Common Terraform Issues

#### State File Lock Issues

```bash
# Check for state locks
terraform force-unlock LOCK_ID

# Or use remote state backend
terraform init -migrate-state
```

#### Provider Authentication Issues

```bash
# Verify AWS credentials
aws configure list

# Refresh credentials
aws sts get-caller-identity

# Set region explicitly
export AWS_DEFAULT_REGION=us-east-1
```

#### Resource Dependency Issues

```bash
# Graph dependencies
terraform graph | dot -Tpng > dependency-graph.png

# Apply in specific order
terraform apply -target=resource_type.resource_name
```

### Common Ansible Issues

#### SSH Connection Issues

```bash
# Test SSH connectivity
ansible -i inventory/aws_ec2.yml all -m ping

# Check SSH config
ansible -i inventory/aws_ec2.yml all -m command -a "whoami"

# Debug SSH issues
ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml -vvv
```

#### Package Installation Issues

```bash
# Update package cache
ansible -i inventory/aws_ec2.yml all -m command -a "yum update -y"

# Check available packages
ansible -i inventory/aws_ec2.yml all -m command -a "yum list available nginx"

# Install with specific version
ansible -i inventory/aws_ec2.yml webservers -m yum \
  -a "name=nginx-1.20.1 state=present"
```

#### Service Issues

```bash
# Check service status
ansible -i inventory/aws_ec2.yml webservers -m command -a "systemctl status nginx"

# Check service logs
ansible -i inventory/aws_ec2.yml webservers -m command -a "journalctl -u nginx -f"

# Restart service
ansible -i inventory/aws_ec2.yml webservers -m service \
  -a "name=nginx state=restarted"
```

## Validation and Testing

### Infrastructure Validation

```bash
# Run Terraform validation
terraform validate

# Check for security issues
checkov --directory terraform/ --framework terraform

# Validate syntax
terraform fmt -check
```

### Configuration Validation

```bash
# Ansible syntax check
ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml --syntax-check

# Run Ansible linter
ansible-lint ansible/

# Dry run execution
ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml --check
```

### End-to-End Testing

```bash
# Run smoke tests
./tests/integration/smoke-test.sh

# Run security tests
./tests/security/compliance-test.sh

# Run disaster recovery test
./tests/disaster-recovery/dr-test.sh
```

## Monitoring and Logging

### Deployment Monitoring

```bash
# Monitor deployment logs
tail -f /var/log/ansible.log

# Watch CloudFormation events
aws logs tail /aws/lambda/deployment-function --follow

# Monitor application logs
aws logs tail /aws/ec2/webserver-application --follow
```

### Health Checks

```bash
# Check load balancer health
aws elb describe-instance-health --load-balancer-name web-lb

# Check application endpoints
for url in https://api.example.com/health https://app.example.com/health; do
  curl -f $url || echo "Health check failed for $url"
done
```

## Rollback Procedures

### Partial Rollback

```bash
# Rollback specific resource
terraform apply -target=aws_instance.web_servers[0] -replace

# Rollback configuration
ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml \
  --tags webserver --extra-vars "@previous-config.yml"
```

### Full Rollback

```bash
# Revert to previous commit
git checkout PREVIOUS_COMMIT_HASH

# Re-deploy previous state
terraform apply

# Re-apply previous configuration
ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml
```

## Post-Deployment Tasks

### Documentation Update

```bash
# Update inventory documentation
ansible-inventory -i inventory/aws_ec2.yml --list > docs/inventory-$(date +%Y%m%d).json

# Generate deployment report
./scripts/generate-deployment-report.sh
```

### Backup Configuration

```bash
# Backup configurations
tar -czf config-backup-$(date +%Y%m%d).tar.gz \
  terraform/aws/terraform.tfvars \
  ansible/inventory/group_vars/

# Upload backup to S3
aws s3 cp config-backup-$(date +%Y%m%d).tar.gz \
  s3://backups/configurations/
```

### Notification

```bash
# Send deployment notification
./scripts/notify-deployment.sh success

# Update team chat
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Deployment completed successfully"}' \
  $SLACK_WEBHOOK_URL
```

## Performance Tuning

### Terraform Performance

```bash
# Parallel execution
export TF_CLI_CONFIG_FILE=~/.terraformrc
echo 'parallelism = 10' > ~/.terraformrc

# Use remote state with locking
terraform backend configure -migrate-state
```

### Ansible Performance

```bash
# Enable pipelining
echo 'pipelining = True' >> ansible.cfg

# Use fact caching
echo 'fact_caching = redis' >> ansible.cfg

# Increase forks
export ANSIBLE_FORKS=20
```

## Security Considerations

### Key Management

```bash
# Use AWS KMS for secrets
aws kms create-key --description "Infrastructure secrets"

# Encrypt sensitive variables
ansible-vault encrypt secrets.yml
```

### Network Security

```bash
# Verify security group rules
aws ec2 describe-security-groups --filters Name=tag:Environment,Values=prod

# Check for open ports
nmap -sS -p 1-65535 loadbalancer.example.com
```

## Automation Scripts

### Complete Deployment Script

```bash
#!/bin/bash
# scripts/deploy-complete.sh

set -e

ENVIRONMENT=${1:-dev}
REGION=${2:-us-east-1}

echo "Starting deployment to $ENVIRONMENT..."

# Export environment variables
export TF_VAR_environment=$ENVIRONMENT
export AWS_DEFAULT_REGION=$REGION

# Terraform deployment
echo "Deploying infrastructure..."
cd terraform/aws
terraform init
terraform apply -auto-approve

# Ansible configuration
echo "Configuring applications..."
cd ../../ansible
ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml

# Validation
echo "Running validation tests..."
cd ..
./tests/integration/smoke-test.sh

echo "Deployment completed successfully!"
```

### Usage:

```bash
# Deploy to development
./scripts/deploy-complete.sh dev us-east-1

# Deploy to production
./scripts/deploy-complete.sh prod us-east-1
```

## Emergency Contacts

| Situation                 | Contact             | Method                     |
| ------------------------- | ------------------- | -------------------------- |
| **Deployment Failure**    | DevOps Lead         | Slack @devops-lead         |
| **Infrastructure Issues** | Infrastructure Team | infrastructure@company.com |
| **Security Incident**     | Security Team       | security@company.com       |
| **After Hours Emergency** | On-call Engineer    | PagerDuty escalation       |

---

_Runbook Version: 1.0_
_Last Updated: November 2025_
_Next Review: February 2026_
