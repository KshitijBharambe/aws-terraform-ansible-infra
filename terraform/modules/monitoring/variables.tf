# Monitoring Module - Input Variables

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

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

#===============================================================================
# Instance Configuration
#===============================================================================

variable "instance_ids" {
  description = "List of EC2 instance IDs to monitor"
  type        = list(string)
  default     = []
}

#===============================================================================
# CloudWatch Log Groups Configuration
#===============================================================================

variable "log_groups" {
  description = "List of log group names to create"
  type        = list(string)
  default     = ["application", "access", "error"]
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 14
}

variable "enable_system_logs" {
  description = "Whether to create system log group"
  type        = bool
  default     = true
}

#===============================================================================
# SNS Notification Configuration
#===============================================================================

variable "alarm_emails" {
  description = "List of email addresses to receive alarm notifications"
  type        = list(string)
  default     = []
}

#===============================================================================
# CPU Monitoring Configuration
#===============================================================================

variable "cpu_threshold" {
  description = "CPU utilization threshold percentage for alarm"
  type        = number
  default     = 80
}

variable "cpu_period" {
  description = "Period in seconds over which CPU metric is evaluated"
  type        = number
  default     = 300
}

variable "cpu_evaluation_periods" {
  description = "Number of periods to evaluate for CPU alarm"
  type        = number
  default     = 2
}

#===============================================================================
# Memory Monitoring Configuration
#===============================================================================

variable "enable_memory_monitoring" {
  description = "Whether to enable memory monitoring (requires CloudWatch Agent)"
  type        = bool
  default     = false
}

variable "memory_threshold" {
  description = "Memory utilization threshold percentage for alarm"
  type        = number
  default     = 85
}

variable "memory_period" {
  description = "Period in seconds over which memory metric is evaluated"
  type        = number
  default     = 300
}

variable "memory_evaluation_periods" {
  description = "Number of periods to evaluate for memory alarm"
  type        = number
  default     = 2
}

#===============================================================================
# Disk Monitoring Configuration
#===============================================================================

variable "enable_disk_monitoring" {
  description = "Whether to enable disk monitoring (requires CloudWatch Agent)"
  type        = bool
  default     = false
}

variable "disk_threshold" {
  description = "Disk utilization threshold percentage for alarm"
  type        = number
  default     = 90
}

variable "disk_period" {
  description = "Period in seconds over which disk metric is evaluated"
  type        = number
  default     = 300
}

variable "disk_evaluation_periods" {
  description = "Number of periods to evaluate for disk alarm"
  type        = number
  default     = 2
}

#===============================================================================
# Status Check Monitoring Configuration
#===============================================================================

variable "enable_status_checks" {
  description = "Whether to enable status check monitoring"
  type        = bool
  default     = true
}

variable "status_check_threshold" {
  description = "Threshold for status check failures"
  type        = number
  default     = 0
}

variable "status_check_period" {
  description = "Period in seconds over which status check metric is evaluated"
  type        = number
  default     = 60
}

variable "status_check_evaluation_periods" {
  description = "Number of periods to evaluate for status check alarm"
  type        = number
  default     = 1
}

#===============================================================================
# Dashboard Configuration
#===============================================================================

variable "enable_dashboard" {
  description = "Whether to create CloudWatch dashboard"
  type        = bool
  default     = false
}

#===============================================================================
# CloudWatch Agent Configuration
#===============================================================================

variable "enable_cloudwatch_agent" {
  description = "Whether to create IAM role and policy for CloudWatch Agent"
  type        = bool
  default     = false
}

#===============================================================================
# Advanced Monitoring Configuration
#===============================================================================

variable "enable_application_monitoring" {
  description = "Whether to enable application-specific monitoring"
  type        = bool
  default     = false
}

variable "custom_metrics" {
  description = "List of custom CloudWatch metrics to monitor"
  type = list(object({
    metric_name         = string
    namespace           = string
    threshold           = number
    comparison_operator = string
    statistic           = string
    period              = number
    evaluation_periods  = number
  }))
  default = []
}

variable "enable_log_metric_filters" {
  description = "Whether to create metric filters for logs"
  type        = bool
  default     = false
}

variable "log_metric_filters" {
  description = "List of log metric filters to create"
  type = list(object({
    name             = string
    pattern          = string
    log_group_name   = string
    metric_name      = string
    metric_value     = number
    metric_namespace = string
  }))
  default = []
}
