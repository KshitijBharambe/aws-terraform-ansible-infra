# Load Balancer Module - Input Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default     = {}
}

#===============================================================================
# Load Balancer Configuration
#===============================================================================

variable "internal" {
  description = "Whether the load balancer is internal"
  type        = bool
  default     = false
}

variable "security_group_ids" {
  description = "List of security group IDs to assign to the load balancer"
  type        = list(string)
}

variable "subnet_ids" {
  description = "List of subnet IDs to attach to the load balancer"
  type        = list(string)
}

variable "enable_deletion_protection" {
  description = "Whether to enable deletion protection for the load balancer"
  type        = bool
  default     = false
}

#===============================================================================
# Access Logs Configuration
#===============================================================================

variable "enable_access_logs" {
  description = "Whether to enable access logs"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket name for access logs"
  type        = string
  default     = ""
}

#===============================================================================
# Target Group Configuration
#===============================================================================

variable "vpc_id" {
  description = "VPC ID where the target group will be created"
  type        = string
}

variable "target_port" {
  description = "Port on which targets receive traffic"
  type        = number
  default     = 80
}

variable "target_protocol" {
  description = "Protocol to use for routing traffic to targets"
  type        = string
  default     = "HTTP"
  
  validation {
    condition     = contains(["HTTP", "HTTPS"], var.target_protocol)
    error_message = "The target_protocol value must be one of: HTTP, HTTPS."
  }
}

variable "target_type" {
  description  = "Type of target that you must specify when registering targets with this target group"
  type         = string
  default      = "instance"
  
  validation {
    condition     = contains(["instance", "ip", "lambda"], var.target_type)
    error_message = "The target_type value must be one of: instance, ip, lambda."
  }
}

variable "target_ids" {
  description = "List of target IDs (instance IDs, IP addresses, or Lambda ARNs)"
  type        = list(string)
  default     = []
}

#===============================================================================
# Health Check Configuration
#===============================================================================

variable "health_check_path" {
  description = "Destination for the health check request"
  type        = string
  default     = "/"
}

variable "health_check_port" {
  description = "Port to use to connect with the target"
  type        = string
  default     = "traffic-port"
}

variable "health_check_protocol" {
  description  = "Protocol to use to connect with the target"
  type         = string
  default      = "HTTP"
  
  validation {
    condition     = contains(["HTTP", "HTTPS", "TCP"], var.health_check_protocol)
    error_message = "The health_check_protocol value must be one of: HTTP, HTTPS, TCP."
  }
}

variable "health_check_interval" {
  description = "Approximate amount of time, in seconds, between health checks of an individual target"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Amount of time, in seconds, during which no response means a failed health check"
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "Number of consecutive health checks successes required before considering an unhealthy target healthy"
  type        = number
  default     = 3
}

variable "unhealthy_threshold" {
  description = "Number of consecutive health check failures required before considering the target unhealthy"
  type        = number
  default     = 3
}

variable "health_check_matcher" {
  description = "HTTP codes to use when checking for a successful response from a target"
  type        = map(string)
  default = {
    "http_codes" = "200"
  }
}

variable "deregistration_delay" {
  description = "Amount time for Elastic Load Balancing to wait before changing the state of a deregistering target from draining to unused"
  type        = number
  default     = 300
}

#===============================================================================
# Session Affinity (Stickiness)
#===============================================================================

variable "enable_stickiness" {
  description = "Whether to enable stickiness"
  type        = bool
  default     = false
}

variable "stickiness_type" {
  description  = "The type of sticky sessions"
  type         = string
  default      = "lb_cookie"
  
  validation {
    condition     = contains(["lb_cookie", "app_cookie"], var.stickiness_type)
    error_message = "The stickiness_type value must be one of: lb_cookie, app_cookie."
  }
}

#===============================================================================
# HTTPS Configuration
#===============================================================================

variable "enable_https" {
  description = "Whether to enable HTTPS listener"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate to use for HTTPS"
  type        = string
  default     = null
}

variable "ssl_policy" {
  description = "Name of the SSL policy for the HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-2016-08"
}

#===============================================================================
# Listener Rules (Optional)
#===============================================================================

variable "listener_rules" {
  description = "List of listener rules for path-based routing"
  type = list(object({
    priority      = number
    path_patterns = list(string)
    target_groups = list(string) # Currently not used, but for future expansion
  }))
  default = []
}
