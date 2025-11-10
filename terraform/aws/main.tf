# AWS Main Terraform Configuration
# Deploys cost-optimized infrastructure for on-demand deployments

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider Configuration
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.common_tags
  }
}

# Data sources for dynamic configuration
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# VPC Module
module "vpc" {
  source = "../modules/vpc"
  
  project_name           = var.project_name
  environment            = var.environment
  vpc_cidr               = var.vpc_cidr
  availability_zones     = var.availability_zones
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs
  enable_nat_gateway     = var.enable_nat_gateway
  enable_vpn_gateway     = var.enable_vpn_gateway
  common_tags            = var.common_tags
}

# Security Module
module "security" {
  source = "../modules/security"
  
  project_name             = var.project_name
  environment              = var.environment
  vpc_id                   = module.vpc.vpc_id
  allowed_ssh_cidr_blocks  = var.allowed_ssh_cidr_blocks
  web_allowed_cidr_blocks  = var.web_allowed_cidr_blocks
  ssh_port                 = var.ssh_port
  web_port                 = var.web_port
  ssl_port                 = var.ssl_port
  common_tags              = var.common_tags
}

# Compute Module - Web Servers
module "web_servers" {
  source = "../modules/compute"
  
  count = var.enable_load_balancer ? var.instance_count : 1
  
  project_name             = "${var.project_name}-web-${count.index}"
  environment              = var.environment
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = var.enable_nat_gateway ? module.vpc.private_subnet_ids : module.vpc.public_subnet_ids
  security_group_ids       = [module.security.web_security_group_id]
  instance_type             = var.instance_type
  ami_id                   = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2.id
  key_name                 = var.key_name
  user_data                = file("${path.module}/user-data-web.sh")
  root_volume_size         = var.root_volume_size
  root_volume_type         = var.root_volume_type
  enable_monitoring        = var.enable_monitoring
  common_tags              = merge(var.common_tags, {
    Role = "WebServer"
  })
}

# Compute Module - App Servers
module "app_servers" {
  source = "../modules/compute"
  
  count = var.instance_count > 1 && !var.enable_load_balancer ? var.instance_count - 1 : 0
  
  project_name             = "${var.project_name}-app-${count.index}"
  environment              = var.environment
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = var.enable_nat_gateway ? module.vpc.private_subnet_ids : module.vpc.public_subnet_ids
  security_group_ids       = [module.security.app_security_group_id]
  instance_type             = var.instance_type
  ami_id                   = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2.id
  key_name                 = var.key_name
  user_data                = file("${path.module}/user-data-app.sh")
  root_volume_size         = var.root_volume_size
  root_volume_type         = var.root_volume_type
  enable_monitoring        = var.enable_monitoring
  common_tags              = merge(var.common_tags, {
    Role = "AppServer"
  })
}

# Load Balancer Module
module "loadbalancer" {
  source = "../modules/loadbalancer"
  count  = var.enable_load_balancer ? 1 : 0
  
  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.public_subnet_ids
  security_group_ids     = [module.security.alb_security_group_id]
  load_balancer_type     = var.load_balancer_type
  web_port               = var.web_port
  ssl_port               = var.ssl_port
  enable_ssl             = var.enable_ssl
  certificate_arn        = var.certificate_arn
  health_check_path      = var.health_check_path
  health_check_interval  = var.health_check_interval
  target_instance_ids    = module.web_servers[*].instance_id
  common_tags            = var.common_tags
}

# Monitoring Module
module "monitoring" {
  source = "../modules/monitoring"
  
  project_name          = var.project_name
  environment           = var.environment
  instance_ids          = concat(
    module.web_servers[*].instance_id,
    module.app_servers[*].instance_id
  )
  alarm_emails         = var.alarm_email != "" ? [var.alarm_email] : []
  cpu_threshold         = var.cpu_threshold
  enable_cloudwatch_alarms = var.enable_cloudwatch_alarms
  common_tags           = var.common_tags
}

# Backup Configuration
resource "aws_backup_plan" "main" {
  count = var.enable_backup ? 1 : 0
  
  name = "${var.project_name}-backup-plan"
  
  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main[0].name
    schedule          = var.backup_schedule
    
    lifecycle {
      delete_after = var.backup_retention_days
    }
  }
  
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-backup-plan"
      Environment = var.environment
      Purpose     = "Backup Configuration"
      ManagedBy   = "Terraform"
    }
  )
}

resource "aws_backup_vault" "main" {
  count = var.enable_backup ? 1 : 0
  
  name = "${var.project_name}-backup-vault"
  
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-backup-vault"
      Environment = var.environment
      Purpose     = "Backup Storage"
      ManagedBy   = "Terraform"
    }
  )
}

resource "aws_backup_selection" "main" {
  count = var.enable_backup ? 1 : 0
  
  name         = "${var.project_name}-backup-selection"
  iam_role_arn = aws_iam_role.backup_role[0].arn
  plan_id      = aws_backup_plan.main[0].id
  
  resources = concat(
    module.web_servers[*].instance_arn,
    module.app_servers[*].instance_arn
  )
}

resource "aws_iam_role" "backup_role" {
  count = var.enable_backup ? 1 : 0
  
  name = "${var.project_name}-backup-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-backup-role"
      Environment = var.environment
      Purpose     = "Backup Service Role"
      ManagedBy   = "Terraform"
    }
  )
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  count      = var.enable_backup ? 1 : 0
  role       = aws_iam_role.backup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  depends_on = [aws_iam_role.backup_role]
}

# Cost Management
resource "aws_budgets_budget" "monthly" {
  count = var.monthly_budget_limit > 0 ? 1 : 0
  
  name              = "${var.project_name}-monthly-budget"
  budget_type       = "COST"
  time_unit         = "MONTHLY"
  budget_amount     = var.monthly_budget_limit
  
  cost_filters = {
    Service = "Amazon EC2", "Amazon ELB", "Amazon VPC", "Amazon CloudWatch"
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.budget_threshold
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alarm_email != "" ? [var.alarm_email] : []
  }
  
  tags = var.common_tags
}

# Cost Anomaly Detection
resource "aws_ce_anomaly_subscription" "main" {
  count = var.enable_cost_anomaly_detection ? 1 : 0
  
  name      = "${var.project_name}-cost-anomaly-detection"
  frequency = "DAILY"
  
  monitor_arn_list = [aws_ce_anomaly_monitor.main[0].arn]
  
  subscriber {
    type        = "EMAIL"
    address     = var.alarm_email
    subscribe   = "YES"
  }
}

resource "aws_ce_anomaly_monitor" "main" {
  count = var.enable_cost_anomaly_detection ? 1 : 0
  
  name             = "${var.project_name}-cost-monitor"
  monitor_type     = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

# Instance Profile for SSM access (for management)
resource "aws_iam_instance_profile" "ssm" {
  name = "${var.project_name}-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_iam_role" "ssm_role" {
  name = "${var.project_name}-ssm-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-ssm-role"
      Environment = var.environment
      Purpose     = "SSM Access"
      ManagedBy   = "Terraform"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  depends_on = [aws_iam_role.ssm_role]
}

# CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "application" {
  name = "/aws/ec2/${var.project_name}"
  
  retention_in_days = var.terraform_log_retention_days
  
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-application-logs"
      Environment = var.environment
      Purpose     = "Application Logs"
      ManagedBy   = "Terraform"
    }
  )
}

# SNS Topic for operational notifications
resource "aws_sns_topic" "operations" {
  name = "${var.project_name}-operations"
  
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-operations"
      Environment = var.environment
      Purpose     = "Operational Notifications"
      ManagedBy   = "Terraform"
    }
  )
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.operations.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}
