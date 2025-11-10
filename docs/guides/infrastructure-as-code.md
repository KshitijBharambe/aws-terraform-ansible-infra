# Infrastructure as Code (IaC) Guide

This guide provides comprehensive instructions for implementing Infrastructure as Code practices for your AWS Terraform Ansible project.

## Overview

Infrastructure as Code (IaC) is the practice of managing and provisioning infrastructure through machine-readable definition files, rather than through manual configuration processes.

## Core IaC Principles

### 1. Declarative Configuration

- **Infrastructure is defined as code**: Use high-level languages to define infrastructure
- **Desired state management**: Continuously converge to the desired state
- **Idempotent operations**: Multiple applications result in the same final state

### 2. Version Control Integration

- **All infrastructure code in version control**
- **Branching strategy for environments**
- **Pull requests for code review**
- **Audit trail for all changes**

### 3. Automated Testing and Validation

- **Pre-deployment validation**: Test infrastructure before deployment
- **Post-deployment verification**: Confirm infrastructure is working as expected
- **Automated testing**: Include infrastructure tests in CI/CD pipeline

### 4. Continuous Integration/Continuous Deployment (CI/CD)

- **Automated pipeline for infrastructure changes**
- **Environment-specific configurations**
- **Rollback capabilities**

## Project Structure

### 1. Repository Organization

```
infrastructure-as-code/
├── README.md                    # Project documentation
├── .gitignore                   # Git ignore file
├── .pre-commit-config.yaml       # Pre-commit hooks
├── docs/                         # Documentation
│   ├── architecture/            # Architecture documentation
│   ├── guides/                 # Implementation guides
│   └── runbooks/              # Operational procedures
├── terraform/                    # Terraform code
│   ├── aws/                     # AWS infrastructure
│   │   ├── main.tf              # Main configuration
│   │   ├── variables.tf          # Variable definitions
│   │   ├── outputs.tf             # Output definitions
│   │   ├── modules/              # Reusable modules
│   │   │   ├── vpc/           # VPC module
│   │   │   ├── security/       # Security module
│   │   │   └── monitoring/     # Monitoring module
│   │   ├── environments/          # Environment-specific configs
│   │   │   ├── dev/            # Development environment
│   │   │   ├── staging/         # Staging environment
│   │   │   └── prod/           # Production environment
│   │   └── tests/               # Terraform tests
│   ├── oci/                     # OCI infrastructure
│   │   └── localstack/            # Local development
├── ansible/                      # Ansible code
│   ├── playbooks/               # Playbooks
│   │   ├── site.yml              # Site configuration
│   │   ├── webserver/           # Web server configuration
│   │   ├── database/             # Database configuration
│   │   ├── monitoring/           # Monitoring setup
│   │   └── security/             # Security hardening
│   ├── roles/                    # Reusable roles
│   │   ├── webserver/           # Web server role
│   │   │   ├── tasks/             # Tasks
│   │   │   ├── templates/          # Templates
│   │   │   ├── vars/               # Variables
│   │   │   └── handlers/           # Handlers
│   │   ├── backup/                # Backup role
│   │   └── monitoring/            # Monitoring role
│   ├── inventory/                 # Inventory files
│   │   ├── aws/                  # AWS hosts
│   │   ├── oci/                  # OCI hosts
│   │   └── localstack/           # Local hosts
│   └── tests/                    # Ansible tests
├── scripts/                       # Helper scripts
│   ├── setup.sh                  # Environment setup
│   ├── validate.sh               # Infrastructure validation
│   ├── deploy.sh                  # Deployment automation
│   └── test.sh                   # Test execution
├── tests/                         # Test files
│   ├── unit/                      # Unit tests
│   ├── integration/               # Integration tests
│   ├── security/                  # Security tests
│   └── fixtures/                  # Test data
├── pipelines/                      # CI/CD pipeline definitions
│   ├── github-actions/            # GitHub Actions workflows
│   ├── gitlab-ci/               # GitLab CI pipelines
│   └── jenkins/                  # Jenkins pipeline definitions
└── tools/                         # Additional tools
    ├── compliance/                 # Compliance checking
    ├── cost-optimization/         # Cost optimization
    └── security/                  # Security scanning
```

### 2. Branching Strategy

```mermaid
graph TD
    main["main"] -->|development|
    main["main"] -->|staging|
    main["main"] -->|production|

    development["develop"] -->|main|
    staging["staging"] -->|main|
    production["prod"] -->|main|

    feature["feature/*"] -->|development
    hotfix["hotfix/*"] -->|main

    main["main"] -->|release/*
```

**Branch Types:**

- `main`: Production-ready code
- `develop`: Active development branch
- `staging`: Pre-production testing branch
- `feature/*`: Feature development branches
- `hotfix/*`: Emergency fixes
- `release/*`: Tagged releases

## Terraform Best Practices

### 1. Module Structure

**Module Organization**

```
terraform/
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── security/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── monitoring/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
└── environments/
    ├── dev/
    │   ├── backend.tf
    │   ├── main.tf
    │   └── terraform.tfvars
    ├── staging/
    │   ├── backend.tf
    │   ├── main.tf
    │   └── terraform.tfvars
    └── prod/
        ├── backend.tf
        ├── main.tf
        └── terraform.tfvars
```

### 2. VPC Module

**VPC Module: `terraform/modules/vpc/main.tf`**

```hcl
variable "name" {
  description = "Name of the VPC"
  type        = string
}

variable "cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = []
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames for instances"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# VPC Resource
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  tags                 = merge(var.tags, {
    Name = "${var.name}-vpc"
    Environment = var.tags["Environment"]
  })
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, {
    Name = "${var.name}-igw"
    Environment = var.tags["Environment"]
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name}-public-subnet-${count.index}"
    Type = "Public"
    Environment = var.tags["Environment"]
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index + 10)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-private-subnet-${count.index}"
    Type = "Private"
    Environment = var.tags["Environment"]
  })
}

# NAT Gateway
resource "aws_eip" "nat" {
  count     = length(var.availability_zones)
  vpc       = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-nat-eip-${count.index}"
    Environment = var.tags["Environment"]
  })
}

resource "aws_nat_gateway" "this" {
  allocation_id = "eipalloc"
  subnet_ids     = aws_subnet.private[*].id

  tags = merge(var.tags, {
    Name = "${var.name}-nat"
    Environment = var.tags["Environment"]
  })
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-public-rt"
    Environment = var.tags["Environment"]
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-public-igw-route"
    Environment = var.tags["Environment"]
  })
}

resource "aws_route" "private_nat" {
  count                  = length(var.availability_zones)
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-private-nat-route-${count.index}"
    Environment = var.tags["Environment"]
  })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count         = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count         = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.public.id
}

# VPC Flow Logs
resource "aws_flow_log" "this" {
  iam_role_arn   = var.flow_log_iam_role_arn
  log_destination = aws_cloudwatch_log_group.vpc.arn
  traffic_type    = "ALL"
  vpc_id         = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-flow-logs"
    Environment = var.tags["Environment"]
  }
}

resource "aws_cloudwatch_log_group" "vpc" {
  name = "/aws/vpc/flow-logs/${var.name}"

  tags = merge(var.tags, {
    Name = "${var.name}-flow-logs"
    Environment = var.tags["Environment"]
  }
}
```

### 3. Security Module

**Security Module: `terraform/modules/security/main.tf`**

```hcl
variable "vpc_id" {
  description = "VPC ID for security groups"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for security group names"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all security resources"
  type        = map(string)
  default     = {}
}

variable "allowed_ip_ranges" {
  description = "List of allowed IP ranges"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "List of allowed CIDR blocks"
  type        = list(string)
  default     = []
}

# Web Security Group
resource "aws_security_group" "web" {
  name        = "${var.name_prefix}-web-sg"
  description = "Security group for web servers"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-web-sg"
    Environment = var.tags["Environment"]
  })

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "SSH from allowed IP ranges"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ip_ranges
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Database Security Group
resource "aws_security_group" "database" {
  name        = "${var.name_prefix}-db-sg"
  description = "Security group for database servers"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-sg"
    Environment = var.tags["Environment"]
  })
}

  ingress {
    description = "Database access from web servers"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description = "Database access from bastion hosts"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "Database outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Security Group
resource "aws_security_group" "application" {
  name        = "${var.name_prefix}-app-sg"
  description = "Security group for application servers"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-app-sg"
    Environment = var.tags["Environment"]
  })
}

  ingress {
    description = "Application access from load balancers"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Application access from other application servers"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.application.id]
  }

  egress {
    description = "Application outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Load Balancer Security Group
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Security group for application load balancer"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
    Environment = var.tags["Environment"]
  })
}

  ingress {
    description = "HTTP traffic from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "HTTPS traffic from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "Load balancer outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### 4. Monitoring Module

**Monitoring Module: `terraform/modules/monitoring/main.tf`**

```hcl
variable "name_prefix" {
  description = "Prefix for monitoring resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for monitoring resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all monitoring resources"
  type        = map(string)
  default     = {}
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring (additional cost)"
  type        = bool
  default     = true
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "application" {
  name = "/aws/ec2/${var.name_prefix}/application"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-application-logs"
    Environment = var.tags["Environment"]
  })
}

resource "aws_cloudwatch_log_group" "nginx" {
  name = "/aws/ec2/${var.name_prefix}/nginx"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nginx-logs"
    Environment = var.tags["Environment"]
  })
}

resource "aws_cloudwatch_log_group" "database" {
  name = "/aws/rds/${var.name_prefix}/database"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-database-logs"
    Environment = var.tags["Environment"]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.name_prefix}-high-cpu"
  comparison_operator   = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace          = "AWS/EC2"
  period             = "300"
  statistic          = "Average"
  threshold          = "80"
  alarm_description   = "This metric monitors ec2 cpu for high utilization"
  alarm_actions      = [aws_cloudwatch_log_group.application.arn]
  ok_actions         = [aws_cloudwatch_log_group.application.arn]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-high-cpu-alarm"
    Environment = var.tags["Environment"]
  })
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.name_prefix}-high-memory"
  comparison_operator   = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace          = "CWAgent"
  period             = "300"
  statistic          = "Average"
  threshold          = "85"
  alarm_description   = "This metric monitors ec2 memory for high utilization"
  alarm_actions      = [aws_cloudwatch_log_group.application.arn]
  ok_actions         = [aws_cloudwatch_log_group.application.arn]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-high-memory-alarm"
    Environment = var.tags["Environment"]
  })
}

# CloudWatch Log Subscription Filters
resource "aws_log_subscription_filter" "application_errors" {
  name           = "${var.name_prefix}-application-errors"
  pattern_string = "{ $.messageType = \"ERROR\" }"
  log_group_name = aws_cloudwatch_log_group.application.name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-application-errors"
    Environment = var.tags["Environment"]
  })
}

resource "aws_cloudwatch_metric_filter" "nginx_status" {
  name       = "${var.name_prefix}-nginx-status"
  pattern    = "{ $.server.status != \"200\" }"
  metric_name = "NginxStatus"
  namespace = "NginxMetrics"
  value      = "1"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nginx-status"
    Environment = var.tags["Environment"]
  })
}

# SNS Topics for Alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alerts"
    Environment = var.tags["Environment"]
  })
}

# CloudWatch Alarms with SNS Notifications
resource "aws_cloudwatch_metric_alarm" "critical_alerts" {
  alarm_name        = "${var.name_prefix}-critical-alerts"
  alarm_description = "Critical infrastructure alerts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = "1"
  metric_name = "ErrorRate"
  namespace = "AWS/ApplicationELB"
  period = "300"
  statistic = "Average"
  threshold = "5"
  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-critical-alerts"
    Environment = var.tags["Environment"]
  })
}
```

### 5. Environment-Specific Configurations

**Development Environment: `terraform/environments/dev/terraform.tfvars`**

```hcl
# Development Environment Variables
environment = "dev"

# AWS Region
aws_region = "us-east-1"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Instance Configuration
web_server_instance_type = "t3.medium"
app_server_instance_type = "t3.small"
database_instance_class = "db.t3.micro"

# Application Configuration
app_version = "latest"
database_password = "dev_password_123"

# Monitoring Configuration
enable_detailed_monitoring = "true"

# Tags
tags = {
  Environment = "dev"
  Project = "infrastructure-as-code"
  ManagedBy = "Terraform"
}
```

**Production Environment: `terraform/environments/prod/terraform.tfvars`**

```hcl
# Production Environment Variables
environment = "prod"

# AWS Region
aws_region = "us-east-1"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Instance Configuration
web_server_instance_type = "m5.large"
app_server_instance_type = "m5.large"
database_instance_class = "db.m5.large"

# Application Configuration
app_version = "v1.0.0"
database_password = "prod_password_secure_456"

# Monitoring Configuration
enable_detailed_monitoring = "true"

# Tags
tags = {
  Environment = "prod"
  Project = "infrastructure-as-code"
  ManagedBy = "Terraform"
  CostCenter = "engineering"
}
```

## Ansible Best Practices

### 1. Role Structure

**Role Organization**

```
ansible/roles/
├── webserver/
│   ├── README.md
│   ├── tasks/
│   │   ├── main.yml
│   │   ├── install.yml
│   │   ├── configure.yml
│   │   └── deploy.yml
│   ├── templates/
│   │   ├── nginx.conf.j2
│   │   ├── apache.conf.j2
│   │   └── index.html.j2
│   ├── vars/
│   │   ├── main.yml
│   │   ├── RedHat.yml
│   │   └── Ubuntu.yml
│   ├── handlers/
│   │   ├── main.yml
│   │   └── restart.yml
│   ├── meta/
│   │   └── main.yml
│   └── tests/
│       ├── test_install.py
│       ├── test_configure.py
│       └── test_deploy.py
├── backup/
│   ├── README.md
│   ├── tasks/
│   │   ├── main.yml
│   │   ├── setup.yml
│   │   ├── database.yml
│   │   ├── application.yml
│   │   └── cleanup.yml
│   ├── templates/
│   │   ├── backup-config.j2
│   │   ├── system-backup.sh.j2
│   │   └── database-backup.sh.j2
│   └── vars/
│       └── main.yml
└── monitoring/
    ├── README.md
    ├── tasks/
    │   ├── main.yml
    │   ├── setup.yml
    │   ├── alerts.yml
    │   └── dashboard.yml
    ├── templates/
    │   ├── grafana-dashboard.j2
    │   └── prometheus-config.j2
    └── vars/
        └── main.yml
```

### 2. Playbook Structure

**Site Playbook: `ansible/playbooks/site.yml`**

```yaml
---
- name: Configure Infrastructure as Code Deployment
  hosts: all
  become: yes
  gather_facts: yes

  vars:
    environment: "{{ lookup('env', 'ENVIRONMENT', default='dev') }}"
    terraform_dir: "{{ lookup('env', 'TERRAFORM_DIR', default='/opt/terraform') }}"
    state_file: "{{ terraform_dir }}/{{ environment }}/terraform.tfstate"

  pre_tasks:
    - name: Validate Terraform state exists
      stat:
        path: "{{ state_file }}"
      register: terraform_state

    - name: Load Terraform outputs
      when: terraform_state.stat.exists
      uri:
        url: "file://{{ state_file }}"
      register: terraform_outputs

  tasks:
    - name: Apply web server configuration
      when: "'webserver' in group_names"
      include_role:
        name: webserver
        tasks_from: webserver
      vars:
        environment: "{{ environment }}"
        terraform_outputs: "{{ terraform_outputs.json | from_json }}"

    - name: Configure backup system
      when: "'backup' in group_names"
      include_role:
        name: backup
        tasks_from: backup
      vars:
        environment: "{{ environment }}"
        terraform_outputs: "{{ terraform_outputs.json | from_json }}"

    - name: Set up monitoring
      when: "'monitoring' in group_names"
      include_role:
        name: monitoring
        tasks_from: monitoring
      vars:
        environment: "{{ environment }}"
        terraform_outputs: "{{ terraform_outputs.json | from_json }}"

  post_tasks:
    - name: Generate deployment report
      template:
        src: reports/deployment-report.j2
        dest: "/tmp/deployment-report-{{ environment }}.txt"
      vars:
        deployment_time: "{{ ansible_date_time.isoformat() }}"
        deployment_status: "completed"
        environment: "{{ environment }}"

    - name: Send deployment notification
      when: "'{{ notifications_enabled }}' in group_names"
      mail:
        to: "{{ lookup('env', 'ALERT_EMAIL', default='admin@example.com') }}"
        subject: "IaC Deployment Complete - {{ environment }}"
        body: "{{ lookup('file', '/tmp/deployment-report-' + environment + '.txt') }}"
```

### 3. Idempotent Tasks

**Idempotent Configuration Management**

```yaml
# tasks/configure.yml
---
- name: Ensure configuration directory exists
  file:
    path: "{{ config_dir }}"
    state: directory
    mode: "0755"
    owner: root
    group: root

- name: Configure main configuration file
  template:
    src: "{{ config_template }}"
    dest: "{{ config_file }}"
    mode: "0644"
    owner: root
    group: root
    backup: yes
  notify: Restart service
  register: config_changed

- name: Validate configuration
  command: "{{ config_validate_command }} -t {{ config_file }}"
  register: config_validation
  failed_when: false
  changed_when: false

- name: Log configuration validation
  when: not config_validation.skipped
  uri:
    url: "{{ log_endpoint }}"
    method: POST
    body:
      validation: "success"
      config_file: "{{ config_file }}"
      timestamp: "{{ ansible_date_time.isoformat() }}"
    headers:
      Content-Type: application/json
      Authorization: "Bearer {{ log_api_token }}"
  register: log_result
  ignore_errors: true
```

## Testing Strategy

### 1. Test Types

**Unit Tests**

```python
# tests/unit/test_terraform_modules.py
import pytest
import tempfile
import os
from terraform import Terraform

class TestVPCModule:
    def test_vpc_creation(self):
        """Test VPC module creation"""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create test Terraform configuration
            config = """
provider "aws" {
  region = "us-east-1"
}

module "test_vpc" {
  source = "../../modules/vpc"

  name = "test-vpc"
  cidr = "10.0.0.0/24"

  tags = {
    Name = "test-vpc"
    Environment = "test"
  }
}
"""
            config_file = os.path.join(tmpdir, "main.tf")
            with open(config_file, 'w') as f:
                f.write(config)

            # Initialize Terraform
            tf = Terraform(working_dir=tmpdir)
            tf.init()

            # Plan and apply
            tf.plan()
            result = tf.apply(auto_approve=True)

            # Verify VPC was created
            vpc_id = tf.output('vpc_id')['value']
            assert vpc_id is not None
            assert vpc_id.startswith('vpc-')

            # Clean up
            tf.destroy()

    def test_vpc_variables(self):
        """Test VPC module variables"""
        with tempfile.TemporaryDirectory() as tmpdir:
            config = """
module "test_vpc" {
  source = "../../modules/vpc"

  name = "test-vpc"
  cidr = "10.0.0.0/24"

  tags = {
    Name = "test-vpc"
    Environment = "test"
  }
}
"""
            config_file = os.path.join(tmpdir, "variables.tf")
            with open(config_file, 'w') as f:
                f.write(config)

            # Load variables
            tf = Terraform(working_dir=tmpdir)
            tf.init()

            # Validate variables
            output = tf.validate()
            assert output == 0  # Success

            # Clean up
            tf.destroy()

if __name__ == '__main__':
    pytest.main([TestVPCModule])
```

**Integration Tests**

```python
# tests/integration/test_deployment.py
import pytest
import requests
import time
import json

class TestDeployment:
    def __init__(self, deployment_config):
        self.config = deployment_config
        self.session = requests.Session()

    def test_webserver_accessibility(self):
        """Test web server accessibility"""
        web_server_url = self.config['web_server_url']

        response = self.session.get(web_server_url, timeout=10)
        assert response.status_code == 200
        assert 'Web server is running' in response.text

        # Test endpoints
        health_response = self.session.get(f"{web_server_url}/health", timeout=10)
        assert health_response.status_code == 200

        health_data = health_response.json()
        assert 'status' in health_data
        assert health_data['status'] == 'healthy'

    def test_database_connectivity(self):
        """Test database connectivity"""
        db_config = self.config['database']

        # Test database connection
        try:
            # Add database connection test here
            pass
        except Exception as e:
            pytest.fail(f"Database connection failed: {e}")

    def test_backup_functionality(self):
        """Test backup functionality"""
        backup_url = self.config['backup_api_url']

        # Test backup creation
        response = self.session.post(f"{backup_url}/create", timeout=30)
        assert response.status_code in [200, 201]

        backup_job_id = response.json()['job_id']
        assert backup_job_id is not None

        # Wait for backup completion
        self._wait_for_backup_completion(backup_job_id)

        # Verify backup integrity
        backup_files = self.session.get(f"{backup_url}/files/{backup_job_id}", timeout=10)
        assert backup_files.status_code == 200

        files_data = backup_files.json()
        assert len(files_data) > 0

        for file_info in files_data:
            assert file_info['size'] > 0
            assert file_info['checksum'] is not None

    def _wait_for_backup_completion(self, job_id):
        """Wait for backup job completion"""
        max_wait_time = 300  # 5 minutes
        wait_interval = 5

        elapsed_time = 0
        while elapsed_time < max_wait_time:
            response = self.session.get(f"{backup_url}/jobs/{job_id}", timeout=10)
            job_data = response.json()

            if job_data['status'] in ['completed', 'failed']:
                break

            time.sleep(wait_interval)
            elapsed_time += wait_interval

        assert job_data['status'] == 'completed'
        assert job_data['files_count'] > 0

if __name__ == '__main__':
    # Load configuration
    with open('tests/fixtures/deployment_config.json', 'r') as f:
        config = json.load(f)

    # Run tests
    test_deployment = TestDeployment(config)
    test_deployment.test_webserver_accessibility()
    test_deployment.test_database_connectivity()
    test_deployment.test_backup_functionality()
```

### 2. Test Automation

**Test Execution Script**

```bash
#!/bin/bash
# test.sh

set -e

TEST_TYPE=${1:-all}
ENVIRONMENT=${2:-dev}
CLOUD=${3:-aws}

echo "Running tests: $TEST_TYPE for $ENVIRONMENT on $CLOUD"

# Activate virtual environment
python -m venv .venv && source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run tests based on type
case $TEST_TYPE in
    unit)
        echo "Running unit tests"
        python -m pytest tests/unit/ -v --junitxml=unit-test-results.xml
        ;;
    integration)
        echo "Running integration tests"
        python -m pytest tests/integration/ -v --junitxml=integration-test-results.xml --env $ENVIRONMENT --cloud $CLOUD
        ;;
    security)
        echo "Running security tests"
        python -m pytest tests/security/ -v --junitxml=security-test-results.xml
        ;;
    performance)
        echo "Running performance tests"
        python -m pytest tests/performance/ -v --junitxml=performance-test-results.xml --env $ENVIRONMENT --cloud $CLOUD
        ;;
    compliance)
        echo "Running compliance tests"
        python -m pytest tests/compliance/ -v --junitxml=compliance-test-results.xml --env $ENVIRONMENT --cloud $CLOUD
        ;;
    all)
        echo "Running all tests"
        python -m pytest tests/ -v --junitxml=all-test-results.xml
        ;;
    *)
        echo "Unknown test type: $TEST_TYPE"
        exit 1
        ;;
esac

echo "Tests completed successfully"
```

## Version Control Integration

### 1. Git Workflow

**Branch Protection Rules**

```yaml
# .github/workflows/branch-protection.yml
name: Branch Protection

on:
  pull_request:
    branches:
      - main
      - develop

jobs:
  protect-main:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Prevent force pushes to main
        run: |
          if [ "${{ github.event.pull_request.forced }}" = "true" ]; then
            echo "Force pushes to main are not allowed"
            exit 1
          fi

      - name: Check for required approvals
        run: |
          # Check if PR has required approvals
          if [ "${{ github.event.pull_request.review_decision }}" != "approved" ]; then
            echo "PR requires approval before merge"
            exit 1
          fi
```

### 2. Pre-commit Hooks

**Pre-commit Configuration**

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: terraform-fmt
        name: Terraform Format Check
        entry: terraform fmt -recursive -check
        language: system
        pass: true
        files: \.tf$

      - id: terraform-validate
        name: Terraform Validate
        entry: terraform validate
        language: system
        files: \.tf$

      - id: terraform-docs
        name: Terraform Documentation
        entry: terraform-docs
        language: system
        files: \.tf$
        pass: true
      - id: terraform-tflint
        name: Terraform Lint
        entry: tflint
        language: system
        files: \.tf$

      - id: ansible-lint
        name: Ansible Lint
        entry: ansible-lint
        language: system
        files: \.yml$
        pass: true

      - id: check-json
        name: Check JSON files
        entry: python -m json.tool
        language: system
        files: \.json$
        pass: true

      - id: check-yaml
        name: Check YAML files
        entry: python -m yaml
        language: system
        files: \.yaml$
        pass: true

      - id: trailing-whitespace
        name: Trim Trailing Whitespace
        entry: trailing-whitespace-fixer
        language: system
        types: [text, markdown, json, yaml, terraform]
        pass: true

ci:
  skip: [ansible-lint, terraform-docs]
```

### 3. Code Review Guidelines

**Pull Request Template**

```markdown
## Infrastructure Changes

### Type of Change

- [ ] New infrastructure
- [ ] Existing infrastructure modification
- [ ] Bug fix
- [ ] Performance improvement
- [ ] Security enhancement

### Description

Brief description of the infrastructure changes.

### Testing

- [ ] Unit tests passing
- [ ] Integration tests executed
- [ ] Manual testing completed
- [ ] Performance impact assessed

### Security Considerations

- [ ] Security review completed
- [ ] Access permissions reviewed
- [ ] Encryption requirements met
- [ ] Compliance requirements met

### Rollback Plan

- [ ] Rollback strategy documented
- [ ] Rollback procedures tested
- [ ] Rollback automation available

### Checklist

- [ ] Terraform files formatted correctly
- [ ] All variables defined
- [ ] No hardcoded secrets
- [ ] Documentation updated
- [ ] Tests passing
- [ ] Peer review completed
```

## CI/CD Integration

### 1. Pipeline Orchestration

**GitHub Actions Pipeline**

```yaml
# .github/workflows/infrastructure.yml
name: Infrastructure Deployment

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  validate-infrastructure:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: "1.5.*"

      - name: Validate Terraform
        run: |
          cd terraform
          terraform fmt -recursive -check
          terraform validate

      - name: Setup Ansible
        uses: actions/setup-python@v4
        with:
          python-version: "3.9"

      - name: Install dependencies
        run: |
          pip install ansible ansible-lint

      - name: Validate Ansible
        run: |
          ansible-playbook --syntax-check ansible/playbooks/*.yml

      - name: Run security scan
        uses: aquasec/trivy-action@master
        with:
          scan-type: "fs"
          scan-ref: "."
          format: "sarif"
          output: "trivy-results.sarif"
        continue-on-error: true

  deploy-infrastructure:
    needs: validate-infrastructure
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment:
      ENVIRONMENT: prod
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Deploy infrastructure
        run: |
          cd terraform
          terraform init
          terraform workspace select $ENVIRONMENT
          terraform plan -out=tfplan
          terraform apply -auto-approve
        env:
          TF_LOG: INFO
          TF_INPUT: false
        continue-on-error: false

      - name: Configure application
        run: |
          ansible-playbook -i inventory/aws/hosts \
                        ansible/playbooks/site.yml \
                        -e "environment=$ENVIRONMENT"
```

### 2. Multi-Environment Deployment

**Environment-Specific Configuration**

```yaml
# environments/staging/terraform.tfvars
environment = "staging"

# Infrastructure sizing
web_server_count = 2
web_server_instance_type = "t3.medium"
app_server_count = 1
app_server_instance_type = "t3.small"
database_instance_class = "db.t3.small"

# Configuration differences
enable_detailed_monitoring = false
backup_retention_days = 14
log_retention_days = 7

# Development overrides
dev_specific_overrides = {
  web_server_count: 1,
  web_server_instance_type: "t3.small",
  app_server_instance_type: "t3.micro"
  database_instance_class: "db.t3.micro"
  enable_detailed_monitoring = true,
  backup_retention_days = 7,
  log_retention_days = 3
}

# Production overrides
prod_specific_overrides = {
  web_server_count: 4,
  web_server_instance_type: "m5.large",
  app_server_count = 2,
  app_server_instance_type = "m5.large",
  database_instance_class: "db.m5.large",
  enable_detailed_monitoring = true,
  backup_retention_days = 30,
  log_retention_days = 14
}
```

### 3. Canary Deployments

**Canary Deployment Strategy**

```yaml
# pipelines/canary-deployment.yml
name: Canary Deployment

on:
  workflow_dispatch:
    inputs:
      version:
        description: "Version to deploy"
        required: true
      environment:
        description: "Target environment"
        required: true
        default: staging

jobs:
  deploy-canary:
    runs-on: ubuntu-latest
    environment:
      ENVIRONMENT: ${{ github.event.inputs.environment }}
      VERSION: ${{ github.event.inputs.version }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          ref: ${{ github.event.inputs.version }}

      - name: Deploy canary
        run: |
          # Deploy canary version
          echo "Deploying canary version ${{ github.event.inputs.version }} to ${{ github.event.inputs.environment }}"

          # Infrastructure deployment
          cd terraform
          terraform workspace select ${{ github.event.inputs.environment }}
          terraform init
          terraform plan -out=canary-plan
          terraform apply -auto-approve -var-file=terraform.tfvars.canary

      - name: Run health checks
        run: |
          # Health check canary
          python tests/integration/test_deployment.py --config tests/fixtures/canary-config.json

      - name: Monitor canary
        run: |
          # Monitor canary performance
          python scripts/monitoring/canary-monitor.py --config tests/fixtures/canary-config.json
```

### 4. Progressive Delivery

**Progressive Deployment Pipeline**

```yaml
# pipelines/progressive-delivery.yml
name: Progressive Delivery

on:
  push:
    branches: [main]

jobs:
  deploy-progressive:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        percentage: [10, 50, 100]

    steps:
      - name: Deploy ${{ matrix.percentage }}%
        run: |
          # Deploy progressive percentage
          echo "Deploying ${{ matrix.percentage }}% to production"

          cd terraform
          terraform workspace select production
          terraform init

          # Generate scaled configuration
          python scripts/scaling/generate-config.py --percentage ${{ matrix.percentage }} --config terraform/terraform.tfvars.prod

          terraform plan -out=progressive-plan
          terraform apply -auto-approve -var-file=terraform.tfvars.scaled
          terraform workspace select production

      - name: Test deployment
        run: |
          python tests/integration/test_deployment.py --env production --percentage ${{ matrix.percentage }}

      - name: Monitor performance
        run: |
          python scripts/monitoring/performance-monitor.py --env production --percentage ${{ matrix.percentage }}
```

## Security Considerations

### 1. Secrets Management

**Encrypted Secrets**

```yaml
# terraform/secrets.tf (encrypted)
variable "db_password" {
description = "Database password"
type        = string
sensitive   = true
}

variable "api_keys" {
description = "API keys"
type        = string
sensitive   = true
}
```

**Vault Integration**

```bash
# scripts/setup-vault.sh
#!/bin/bash

set -e

VAULT_ADDR="${VAULT_ADDR:-https://vault.company.com}"
VAULT_TOKEN="${VAULT_TOKEN}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

# Login to Vault
export VAULT_ADDR=$VAULT_ADDR
export VAULT_TOKEN=$VAULT_TOKEN

# Get secrets from Vault
DB_PASSWORD=$(vault kv get -mount=secret/$ENVIRONMENT db_password)
API_KEYS=$(vault kv get -mount=secret/$ENVIRONMENT api_keys)

echo "Retrieved secrets from Vault for environment: $ENVIRONMENT"

# Export secrets for Terraform
export TF_VAR_db_password="$DB_PASSWORD"
export TF_VAR_api_keys="$API_KEYS"
```

### 2. Access Control

**IAM Policies for Infrastructure**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "rds:*",
        "s3:*",
        "iam:*",
        "cloudformation:*"
        "autoscaling:*",
        "elasticloadbalancing:*",
        "route53:*"
        "cloudwatch:*"
        "logs:*"
        "ssm:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": [
            "us-east-1",
            "us-west-2"
          ]
        }
      }
    },
    {
      "Effect": "Deny",
      "Action": [
        "ec2:Delete*",
        "rds:Delete*",
        "iam:Delete*"
        "cloudformation:DeleteStack"
        "autoscaling:Delete*"
        "route53:Delete*"
        "logs:DeleteLogGroup",
        "ssm:DeleteParameter"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": [
            "us-east-1",
            "us-west-2"
          ]
        }
      }
    }
  ]
}
```

### 3. Compliance Checking

**Compliance Test Suite**

```python
# tests/compliance/test_soc2.py
import pytest

class TestSOC2Compliance:
    def test_logging_requirements(self):
        """Test SOC2 logging requirements"""
        # Verify CloudTrail logging
        assert self.cloudtrail_enabled()

        # Verify log retention
        assert self.log_retention_days() >= 365

        # Verify log encryption
        assert self.log_encryption_enabled()

        # Verify log integrity
        assert self.log_integrity_protection()

    def test_access_control(self):
        """Test SOC2 access control"""
        # Verify MFA requirements
        assert self.mfa_enabled()

        # Verify password policies
        assert self.password_complexity_met()

        # Verify account lockout
        assert self.account_lockout_enabled()

    def test_data_protection(self):
        """Test SOC2 data protection"""
        # Verify encryption at rest
        assert self.encryption_at_rest_enabled()

        # Verify data classification
        assert self.data_classification_enabled()

        # Verify data retention policies
        assert self.data_retention_policy_exists()
```

## Monitoring and Observability

### 1. Infrastructure Monitoring

**Prometheus Configuration**

```yaml
# prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "/etc/prometheus/rules/*.yml"

scrape_configs:
  - job_name: "terraform-apply"
    static_configs:
      - targets:
          - "localhost:9090"
    metrics_path: /metrics
    scrape_interval: 5s
    scrape_timeout: 5s
    relabel_configs:
      - source: terraform
        target_label: terraform_state
        regex: true
        replacement: $1

  - job_name: "ansible-playbook"
    static_configs:
      - targets:
          - "localhost:9091"
    metrics_path: /metrics
    scrape_interval: 10s
    scrape_timeout: 5s
    relabel_configs:
      - source: ansible
        target_label: ansible_playbook
        regex: true
        replacement: $1
```

**Grafana Dashboard**

```json
{
  "dashboard": {
    "id": "infrastructure-overview",
    "title": "Infrastructure Overview",
    "tags": ["infrastructure", "iac"],
    "timezone": "browser",
    "panels": [
      {
        "id": "terraform-state",
        "title": "Terraform State",
        "type": "stat",
        "targets": [
          {
            "expr": "terraform_apply_last_success",
            "legendFormat": "{{state}} - {{timestamp}}",
            "refId": "terraform-state"
          }
        ],
        "gridPos": {
          "h": 1,
          "w": 12,
          "x": 0
        }
      },
      {
        "id": "deployment-frequency",
        "title": "Deployment Frequency",
        "type": "graph",
        "targets": [
          {
            "expr": "increase(terraform_apply_count, 1, 86400)",
            "legendFormat": "Deployments per day",
            "refId": "deployment-frequency"
          }
        ],
        "gridPos": {
          "h": 5,
          "w": 12,
          "x": 0
        }
      },
      {
        "id": "resource-usage",
        "title": "Resource Usage Trends",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(aws_instance_count)",
            "legendFormat": "EC2 Instances",
            "refId": "resource-usage"
          }
        ]
      }
    ],
    "time": {
      "from": "now-30d",
      "to": "now",
      "refresh": "1m"
    }
  }
}
```

### 2. Log Aggregation

**Centralized Logging Strategy**

```yaml
# aws-cloudwatch-config.yml
logs:
  - name: terraform-applies
    files:
      - /opt/terraform/logs/terraform-apply.log
    retention-in-days: 90
    multi-region-aggregation:
      enabled: true
      regions: ["us-east-1", "us-west-2"]

  - name: ansible-playbooks
    files:
      - /var/log/ansible/*.log
    retention-in-days: 30
    multi-region-aggregation:
      enabled: true

  - name: application-logs
    files:
      - /var/log/application/*.log
    retention-in-days: 30
    multi-region-aggregation:
      enabled: true
      regions: ["us-east-1", "us-west-2"]

  - name: security-events
    files:
      - /var/log/audit/audit.log
      - /var/log/auth.log
    retention-in-days: 365
    multi-region-aggregation:
      enabled: true
      regions: ["us-east-1", "us-west-2"]
```

### 3. Alerting Strategy

**Alert Configuration**

```yaml
# alerting/rules.yml
alerts:
  - name: terraform-failure
    condition: "terraform_apply_failed > 0"
    severity: "critical"
    notification:
      type: "email"
      recipients: ["devops@company.com", "security@company.com"]
      template: "terraform-failure"
      throttle:
        interval: 300 # 5 minutes
        max_per_hour: 10

  - name: security-violation
    condition: "security_violations > 0"
    severity: "high"
    notification:
      type: "pagerduty"
      service_key: "your-pagerduty-key"
      severity: "high"
      escalation_policy: "30min"
      template: "security-violation"

  - name: cost-anomaly
    condition: "daily_cost > daily_average * 1.5"
    severity: "warning"
    notification:
      type: "email"
      recipients: ["finance@company.com"]
      template: "cost-anomaly"
      throttle:
        interval: 3600 # 1 hour
        max_per_day: 1
```

## Best Practices Summary

### 1. Code Organization

- Use consistent naming conventions
- Implement proper module structure
- Document all code and configurations
- Use version control for all infrastructure code

### 2. Testing Strategy

- Implement comprehensive testing suite
- Include unit, integration, and security tests
- Automate test execution in CI/CD

### 3. Deployment Strategy

- Use environment-specific configurations
- Implement progressive delivery
- Use canary deployments for critical changes
- Maintain rollback capabilities

### 4. Security Practices

- Use encrypted secrets management
- Implement proper access controls
- Regular security audits
- Compliance checking

### 5. Monitoring and Observability

- Comprehensive infrastructure monitoring
- Centralized logging
- Automated alerting
- Performance tracking

### 6. Documentation

- Document all infrastructure configurations
- Maintain runbooks for operational procedures
- Keep diagrams and architecture documentation up to date
- Provide onboarding materials for team members

This IaC guide provides a comprehensive framework for implementing Infrastructure as Code practices for your AWS Terraform Ansible project, ensuring security, reliability, and maintainability of your infrastructure.
