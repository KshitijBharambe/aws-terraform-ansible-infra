# Security Module - Input Variables

variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "ID of the VPC where security groups will be created"
  type        = string
}

#===============================================================================
# Security Group Configuration
#===============================================================================

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to instances"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production!
}

variable "web_ingress_ports" {
  description = "List of ports to allow for web tier"
  type        = list(number)
  default     = [80, 443]
}

variable "app_ingress_ports" {
  description = "List of ports to allow for app tier (internal only)"
  type        = list(number)
  default     = [8080, 8443]
}

variable "enable_ssh_access" {
  description = "Enable SSH access to instances"
  type        = bool
  default     = true
}

variable "ssh_port" {
  description = "SSH port to allow"
  type        = number
  default     = 22
}

#===============================================================================
# IAM Configuration
#===============================================================================

variable "enable_cloudwatch_access" {
  description = "Grant instances permission to write to CloudWatch"
  type        = bool
  default     = true
}

variable "enable_s3_access" {
  description = "Grant instances permission to access S3"
  type        = bool
  default     = false
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs to grant access to"
  type        = list(string)
  default     = []
}

variable "enable_secrets_manager_access" {
  description = "Grant instances permission to access Secrets Manager"
  type        = bool
  default     = false
}

variable "secrets_manager_arns" {
  description = "List of Secrets Manager secret ARNs to grant access to"
  type        = list(string)
  default     = []
}

variable "enable_ssm_access" {
  description = "Grant instances permission for Systems Manager Session Manager"
  type        = bool
  default     = false
}

#===============================================================================
# Encryption
#===============================================================================

variable "enable_kms" {
  description = "Create KMS keys for encryption (AWS only, not in LocalStack)"
  type        = bool
  default     = false
}

variable "kms_deletion_window_in_days" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30
}

#===============================================================================
# Tags
#===============================================================================

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
