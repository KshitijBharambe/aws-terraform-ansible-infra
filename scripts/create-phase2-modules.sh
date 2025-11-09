#!/bin/bash

set -e

PROJECT_ROOT="/Users/kshtj/CourseWork/Study/Projects/aws-terraform-ansible-infra"
cd "$PROJECT_ROOT"

echo "========================================"
echo "Creating Phase 2 Modules"
echo "========================================"

# Create module directories
echo "Creating module directories..."
mkdir -p terraform/modules/compute
mkdir -p terraform/modules/loadbalancer
mkdir -p terraform/modules/monitoring

echo "✓ Module directories created"

# Create README for compute module
cat > terraform/modules/compute/README.md << 'EOF'
# Compute Module

This module creates EC2 instances with optional Auto Scaling capabilities.

## Features

- EC2 Launch Templates with IMDSv2
- Auto Scaling Groups (optional)
- Individual EC2 instances
- Elastic IPs (optional)
- Target group attachments
- EBS encryption support
- Detailed monitoring

## Usage

```hcl
module "compute" {
  source = "../../modules/compute"

  project_name    = "myproject"
  environment     = "dev"
  ami_id          = "ami-12345678"
  instance_type   = "t3.micro"
  subnet_ids      = module.vpc.public_subnet_ids
  security_group_ids = [module.security.web_security_group_id]
  iam_instance_profile = module.security.instance_profile_name
  
  instance_count  = 2
  enable_auto_scaling = false
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | >= 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name | `string` | n/a | yes |
| ami_id | AMI ID for instances | `string` | n/a | yes |
| instance_type | Instance type | `string` | `"t3.micro"` | no |
| subnet_ids | List of subnet IDs | `list(string)` | n/a | yes |
| security_group_ids | List of security group IDs | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| instance_ids | List of instance IDs |
| private_ips | List of private IP addresses |
| public_ips | List of public IP addresses |
EOF

# Create README for loadbalancer module
cat > terraform/modules/loadbalancer/README.md << 'EOF'
# Load Balancer Module

This module creates an Application Load Balancer with target groups and listeners.

## Features

- Application Load Balancer
- Target groups with health checks
- HTTP and HTTPS listeners
- SSL/TLS certificate support
- Cross-zone load balancing

## Usage

```hcl
module "loadbalancer" {
  source = "../../modules/loadbalancer"

  project_name    = "myproject"
  environment     = "dev"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnet_ids
  security_group_ids = [module.security.web_security_group_id]
  
  target_port     = 80
  health_check_path = "/"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | >= 4.0 |

## Outputs

| Name | Description |
|------|-------------|
| load_balancer_arn | ARN of the load balancer |
| load_balancer_dns_name | DNS name of the load balancer |
| target_group_arn | ARN of the target group |
EOF

# Create README for monitoring module
cat > terraform/modules/monitoring/README.md << 'EOF'
# Monitoring Module

This module creates CloudWatch monitoring resources including log groups, metric alarms, and SNS topics.

## Features

- CloudWatch Log Groups
- CloudWatch Metric Alarms
- SNS Topics for notifications
- CloudWatch Dashboard (optional)
- Metric Filters

## Usage

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  project_name    = "myproject"
  environment     = "dev"
  instance_ids    = module.compute.instance_ids
  alarm_email     = "alerts@example.com"
  
  cpu_threshold   = 80
  enable_dashboard = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | >= 4.0 |

## Outputs

| Name | Description |
|------|-------------|
| log_group_names | List of log group names |
| sns_topic_arn | ARN of the SNS topic |
EOF

echo "✓ README files created"

echo ""
echo "========================================"
echo "Phase 2 Module Structure Ready!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Run this script: chmod +x scripts/create-phase2-modules.sh && ./scripts/create-phase2-modules.sh"
echo "2. I will then create the Terraform files for each module"
echo ""
