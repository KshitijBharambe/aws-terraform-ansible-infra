# AWS Terraform Variables
# Cost-optimized configuration for on-demand deployments

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "infra-demo"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "demo"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "Infrastructure Demo"
    Environment = "demo"
    Owner       = "DevOps Team"
    ManagedBy   = "Terraform"
    CostCenter  = "Engineering"
  }
}

# Cost Optimization Variables
variable "cost_optimization_enabled" {
  description = "Enable cost optimization features"
  type        = bool
  default     = true
}

variable "enable_spot_instances" {
  description = "Use spot instances for cost savings"
  type        = bool
  default     = false # Disabled for reliability in demos
}

variable "enable_savings_plans" {
  description = "Enable AWS Savings Plans"
  type        = bool
  default     = false # Disabled for on-demand demos
}

variable "cost_tracking_tags" {
  description = "Tags for cost allocation and tracking"
  type        = list(string)
  default = [
    "Project",
    "Environment",
    "Owner",
    "ManagedBy",
    "CostCenter"
  ]
}

# Terraform Backend Variables
variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
  default     = "" # Must be provided
}

variable "terraform_state_key" {
  description = "Key for Terraform state file"
  type        = string
  default     = "infra/terraform.tfstate"
}

variable "terraform_lock_table" {
  description = "DynamoDB table for state locking"
  type        = string
  default     = "terraform-state-locks"
}

variable "terraform_state_access_arns" {
  description = "ARNs allowed to access Terraform state"
  type        = list(string)
  default     = [] # Will be set to current user ARN
}

variable "terraform_log_retention_days" {
  description = "Retention period for Terraform logs in days"
  type        = number
  default     = 7
}

# Networking Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway (adds $33/month)"
  type        = bool
  default     = false # CRITICAL: Disabled for cost optimization
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway"
  type        = bool
  default     = false
}

# Compute Variables
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.micro" # ARM-based, cheapest viable option
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "" # Will be looked up based on region
}

variable "key_name" {
  description = "SSH key name for EC2 instances"
  type        = string
  default     = "" # Must be provided
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1 # Minimal for cost optimization
}

variable "enable_auto_scaling" {
  description = "Enable Auto Scaling Group"
  type        = bool
  default     = false # Disabled for cost optimization
}

variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 2
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 1
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 8 # Minimum viable size
}

variable "root_volume_type" {
  description = "Type of root volume"
  type        = string
  default     = "gp3" # Cost-effective storage
}

# Security Variables
variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Should be restricted in production
}

variable "web_allowed_cidr_blocks" {
  description = "CIDR blocks allowed for web access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Web access from anywhere
}

variable "ssh_port" {
  description = "SSH port number"
  type        = number
  default     = 22
}

variable "web_port" {
  description = "Web server port"
  type        = number
  default     = 80
}

variable "ssl_port" {
  description = "SSL/TLS port"
  type        = number
  default     = 443
}

# Load Balancer Variables
variable "enable_load_balancer" {
  description = "Enable Application Load Balancer (adds $22/month)"
  type        = bool
  default     = false # Disabled for cost optimization
}

variable "load_balancer_type" {
  description = "Type of load balancer"
  type        = string
  default     = "application"
}

variable "health_check_path" {
  description = "Health check path for load balancer"
  type        = string
  default     = "/"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "enable_ssl" {
  description = "Enable SSL termination"
  type        = bool
  default     = false # Disabled for cost optimization
}

variable "certificate_arn" {
  description = "ACM certificate ARN for SSL"
  type        = string
  default     = ""
}

# Monitoring Variables
variable "enable_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "alarm_email" {
  description = "Email address for alarm notifications"
  type        = string
  default     = "" # Must be provided for alarms
}

variable "cpu_threshold" {
  description = "CPU utilization threshold for alarms"
  type        = number
  default     = 80
}

variable "memory_threshold" {
  description = "Memory utilization threshold for alarms"
  type        = number
  default     = 85
}

variable "disk_threshold" {
  description = "Disk utilization threshold for alarms"
  type        = number
  default     = 90
}

# Backup Variables
variable "enable_backup" {
  description = "Enable backup configuration"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "backup_schedule" {
  description = "Backup schedule in cron format"
  type        = string
  default     = "0 2 * * *" # Daily at 2 AM
}

# Advanced Configuration Variables
variable "assume_role_arn" {
  description = "ARN of role to assume for deployment"
  type        = string
  default     = ""
}

variable "enable_organizations_integration" {
  description = "Enable AWS Organizations integration"
  type        = bool
  default     = false
}

variable "use_existing_vpc" {
  description = "Use existing VPC instead of creating new one"
  type        = bool
  default     = false
}

variable "existing_vpc_id" {
  description = "ID of existing VPC to use"
  type        = string
  default     = ""
}

variable "enable_dns_management" {
  description = "Enable Route53 DNS management"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name for DNS management"
  type        = string
  default     = ""
}

variable "enable_cloudfront" {
  description = "Enable CloudFront CDN"
  type        = bool
  default     = false # Disabled for cost optimization
}

variable "enable_waf" {
  description = "Enable AWS WAF"
  type        = bool
  default     = false # Disabled for cost optimization
}

# Cost Control Variables
variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 15 # Alert at $15/month
}

variable "budget_threshold" {
  description = "Budget alert threshold percentage"
  type        = number
  default     = 80 # Alert at 80% of budget
}

variable "enable_cost_anomaly_detection" {
  description = "Enable cost anomaly detection"
  type        = bool
  default     = true
}

# On-Demand Deployment Variables
variable "deployment_duration_hours" {
  description = "Expected deployment duration in hours"
  type        = number
  default     = 3 # 3-hour demo sessions
}

variable "enable_auto_cleanup" {
  description = "Enable automatic cleanup after deployment"
  type        = bool
  default     = false # Manual cleanup for demos
}

variable "cleanup_delay_hours" {
  description = "Delay before automatic cleanup in hours"
  type        = number
  default     = 24 # Cleanup after 24 hours
}
