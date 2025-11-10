variable "aws_region" {
  description = "AWS region for LocalStack"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "localstack-demo"
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Environment = "development"
    Project     = "Infrastructure-Automation"
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
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

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (use any value for LocalStack)"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Dummy AMI ID for LocalStack
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "SSH key name"
  type        = string
  default     = ""
}

variable "web_instance_count" {
  description = "Number of web instances"
  type        = number
  default     = 1
}

variable "app_instance_count" {
  description = "Number of app instances"
  type        = number
  default     = 1
}

variable "enable_app_tier" {
  description = "Enable application tier"
  type        = bool
  default     = true
}

variable "enable_load_balancer" {
  description = "Enable load balancer"
  type        = bool
  default     = false
}

variable "create_test_resources" {
  description = "Create test resources"
  type        = bool
  default     = false
}

variable "alarm_email" {
  description = "Email address for alarm notifications"
  type        = string
  default     = "test@example.com"
}

variable "cpu_alarm_threshold" {
  description = "CPU alarm threshold"
  type        = number
  default     = 80
}

variable "memory_alarm_threshold" {
  description = "Memory alarm threshold"
  type        = number
  default     = 85
}

variable "disk_alarm_threshold" {
  description = "Disk alarm threshold"
  type        = number
  default     = 90
}

variable "enable_monitoring_dashboard" {
  description = "Enable monitoring dashboard"
  type        = bool
  default     = false
}
