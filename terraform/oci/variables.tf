# =============================================================================
# Oracle Cloud Infrastructure Variables
# =============================================================================

variable "tenancy_ocid" {
  description = "OCID of the tenancy"
  type        = string
  sensitive   = true
}

variable "user_ocid" {
  description = "OCID of the user"
  type        = string
  sensitive   = true
}

variable "fingerprint" {
  description = "Fingerprint of the user's API key"
  type        = string
  sensitive   = true
}

variable "private_key_path" {
  description = "Path to the private key file"
  type        = string
  sensitive   = true
  default     = "~/.oci/oci_api_key.pem"
}

variable "oci_region" {
  description = "OCI region for primary deployment"
  type        = string
  default     = "us-ashburn-1"
}

variable "secondary_region" {
  description = "OCI region for secondary deployment (DR)"
  type        = string
  default     = "us-phoenix-1"
}

variable "compartment_ocid" {
  description = "OCID of the compartment"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "infra-automation"
}

variable "environment" {
  description = "Environment (dev, staging, production)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

# Network Variables
variable "vcn_cidr" {
  description = "CIDR block for VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# Compute Variables
variable "instance_shape" {
  description = "Shape of the compute instance"
  type        = string
  default     = "VM.Standard2.1"
  
  # Free tier eligible shapes
  validation {
    condition     = contains(["VM.Standard2.1", "VM.Standard.E2.1.Micro", "VM.Standard.A1.Flex"], var.instance_shape)
    error_message = "Instance shape must be one of the free tier eligible shapes."
  }
}

variable "instance_os" {
  description = "Operating system for the instance"
  type        = string
  default     = "Oracle Linux"
}

variable "instance_os_version" {
  description = "Operating system version"
  type        = string
  default     = "8"
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
  sensitive   = true
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

# Storage Variables
variable "boot_volume_size" {
  description = "Size of boot volume in GB"
  type        = number
  default     = 50
}

variable "block_volume_size" {
  description = "Size of additional block volume in GB"
  type        = number
  default     = 100
}

# Database Variables
variable "db_shape" {
  description = "Shape of the database"
  type        = string
  default     = "VM.Standard2.1"
}

variable "db_admin_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_admin_password) >= 12
    error_message = "Database password must be at least 12 characters long."
  }
}

variable "db_storage_size" {
  description = "Database storage size in GB"
  type        = number
  default     = 256
}

# Load Balancer Variables
variable "load_balancer_shape" {
  description = "Shape of the load balancer"
  type        = string
  default     = "flexible"
  
  validation {
    condition     = contains(["flexible", "100Mbps", "400Mbps"], var.load_balancer_shape)
    error_message = "Load balancer shape must be one of: flexible, 100Mbps, 400Mbps."
  }
}

variable "load_balancer_bandwidth" {
  description = "Bandwidth for flexible load balancer"
  type        = number
  default     = 10
}

# Monitoring and Logging Variables
variable "enable_monitoring" {
  description = "Enable monitoring services"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable logging services"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Retention period for logs in days"
  type        = number
  default     = 30
}

# Security Variables
variable "enable_security_lists" {
  description = "Enable security lists"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed for HTTP access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_https_cidrs" {
  description = "CIDR blocks allowed for HTTPS access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Tags
variable "freeform_tags" {
  description = "Free-form tags for resources"
  type        = map(string)
  default = {
    "Project"     = "Infrastructure Automation"
    "Environment"  = "Development"
    "ManagedBy"   = "Terraform"
    "CostCenter"  = "Engineering"
  }
}

variable "defined_tags" {
  description = "Defined tags for resources"
  type        = map(string)
  default = {}
}

# Cost Optimization Variables
variable "use_free_tier" {
  description = "Use only free tier eligible resources"
  type        = bool
  default     = true
}

variable "enable_autoscaling" {
  description = "Enable autoscaling for compute instances"
  type        = bool
  default     = false
}

variable "backup_enabled" {
  description = "Enable backup for compute and storage"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

# Advanced Configuration
variable "enable_vpn" {
  description = "Enable VPN connectivity"
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway"
  type        = bool
  default     = true
}

variable "enable_service_gateway" {
  description = "Enable service gateway"
  type        = bool
  default     = true
}

variable "enable_dhcp_options" {
  description = "Enable custom DHCP options"
  type        = bool
  default     = true
}

# Disaster Recovery Variables
variable "enable_dr" {
  description = "Enable disaster recovery setup"
  type        = bool
  default     = false
}

variable "dr_replication_frequency" {
  description = "DR replication frequency in minutes"
  type        = number
  default     = 60
}

variable "dr_failover_test_enabled" {
  description = "Enable DR failover testing"
  type        = bool
  default     = false
}

# Notification Variables
variable "notification_email" {
  description = "Email for notifications"
  type        = string
  sensitive   = true
}

variable "enable_notifications" {
  description = "Enable OCI Notifications service"
  type        = bool
  default     = true
}

variable "enable_slack_webhook" {
  description = "Enable Slack webhook notifications"
  type        = bool
  default     = false
}

variable "slack_webhook_url" {
  description = "Slack webhook URL"
  type        = string
  sensitive   = true
  default     = ""
}
