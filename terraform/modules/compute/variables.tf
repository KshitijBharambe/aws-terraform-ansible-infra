# Compute Module - Input Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_ids" {
  description = "List of subnet IDs for instance deployment"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to instances"
  type        = list(string)
}

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = ""
}

variable "associate_public_ip" {
  description = "Associate public IP address with instances"
  type        = bool
  default     = true
}

variable "user_data_script" {
  description = "User data script for instance initialization"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Size of root EBS volume in GB"
  type        = number
  default     = 8
}

variable "root_volume_type" {
  description = "Type of root EBS volume (gp3, gp2, io1)"
  type        = string
  default     = "gp3"
}

variable "enable_ebs_encryption" {
  description = "Enable EBS volume encryption"
  type        = bool
  default     = true
}

variable "ebs_kms_key_id" {
  description = "KMS key ID for EBS encryption (optional)"
  type        = string
  default     = ""
}

variable "enable_auto_scaling" {
  description = "Enable Auto Scaling Group"
  type        = bool
  default     = false
}

variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

variable "health_check_type" {
  description = "Health check type for ASG (EC2 or ELB)"
  type        = string
  default     = "EC2"
}

variable "health_check_grace_period" {
  description = "Health check grace period in seconds"
  type        = number
  default     = 300
}

variable "target_group_arns" {
  description = "List of target group ARNs for ASG (if using with ALB)"
  type        = list(string)
  default     = []
}

variable "instance_count" {
  description = "Number of individual instances to create (when not using ASG)"
  type        = number
  default     = 1
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for instances"
  type        = bool
  default     = false
}

variable "enable_termination_protection" {
  description = "Enable termination protection"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "instance_tags" {
  description = "Additional tags specific to instances"
  type        = map(string)
  default     = {}
}

variable "cpu_credits" {
  description = "CPU credit option for T instances (standard or unlimited)"
  type        = string
  default     = "standard"
}

variable "metadata_options" {
  description = "Metadata service configuration"
  type = object({
    http_endpoint               = string
    http_tokens                 = string
    http_put_response_hop_limit = number
  })
  default = {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 required for security
    http_put_response_hop_limit = 1
  }
}
