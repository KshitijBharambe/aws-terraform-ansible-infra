# Monitoring Module - Output Values

#===============================================================================
# CloudWatch Log Groups Outputs
#===============================================================================

output "log_group_names" {
  description = "List of CloudWatch log group names"
  value       = aws_cloudwatch_log_group.application[*].name
}

output "log_group_arns" {
  description = "List of CloudWatch log group ARNs"
  value       = aws_cloudwatch_log_group.application[*].arn
}

output "system_log_group_name" {
  description = "Name of system log group (if created)"
  value       = var.enable_system_logs ? aws_cloudwatch_log_group.system[0].name : null
}

output "system_log_group_arn" {
  description = "ARN of system log group (if created)"
  value       = var.enable_system_logs ? aws_cloudwatch_log_group.system[0].arn : null
}

#===============================================================================
# SNS Topic Outputs
#===============================================================================

output "sns_topic_arn" {
  description = "ARN of SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of SNS topic for alerts"
  value       = aws_sns_topic.alerts.name
}

output "sns_topic_subscription_arns" {
  description = "List of SNS subscription ARNs"
  value       = aws_sns_topic_subscription.email[*].arn
}

#===============================================================================
# CloudWatch Alarms Outputs
#===============================================================================

output "cpu_alarm_arns" {
  description = "List of CPU alarm ARNs"
  value       = aws_cloudwatch_metric_alarm.cpu_high[*].arn
}

output "cpu_alarm_names" {
  description = "List of CPU alarm names"
  value       = aws_cloudwatch_metric_alarm.cpu_high[*].alarm_name
}

output "memory_alarm_arns" {
  description = "List of memory alarm ARNs (if created)"
  value       = aws_cloudwatch_metric_alarm.memory_high[*].arn
}

output "memory_alarm_names" {
  description = "List of memory alarm names (if created)"
  value       = aws_cloudwatch_metric_alarm.memory_high[*].alarm_name
}

output "disk_alarm_arns" {
  description = "List of disk alarm ARNs (if created)"
  value       = aws_cloudwatch_metric_alarm.disk_high[*].arn
}

output "disk_alarm_names" {
  description = "List of disk alarm names (if created)"
  value       = aws_cloudwatch_metric_alarm.disk_high[*].alarm_name
}

output "status_check_alarm_arns" {
  description = "List of status check alarm ARNs (if created)"
  value       = aws_cloudwatch_metric_alarm.status_check_failed[*].arn
}

output "status_check_alarm_names" {
  description = "List of status check alarm names (if created)"
  value       = aws_cloudwatch_metric_alarm.status_check_failed[*].alarm_name
}

output "all_alarm_arns" {
  description = "List of all alarm ARNs"
  value = concat(
    aws_cloudwatch_metric_alarm.cpu_high[*].arn,
    aws_cloudwatch_metric_alarm.memory_high[*].arn,
    aws_cloudwatch_metric_alarm.disk_high[*].arn,
    aws_cloudwatch_metric_alarm.status_check_failed[*].arn
  )
}

output "all_alarm_names" {
  description = "List of all alarm names"
  value = concat(
    aws_cloudwatch_metric_alarm.cpu_high[*].alarm_name,
    aws_cloudwatch_metric_alarm.memory_high[*].alarm_name,
    aws_cloudwatch_metric_alarm.disk_high[*].alarm_name,
    aws_cloudwatch_metric_alarm.status_check_failed[*].alarm_name
  )
}

#===============================================================================
# CloudWatch Dashboard Outputs
#===============================================================================

output "dashboard_name" {
  description = "Name of CloudWatch dashboard (if created)"
  value       = var.enable_dashboard ? aws_cloudwatch_dashboard.main[0].dashboard_name : null
}

output "dashboard_url" {
  description = "URL of CloudWatch dashboard (if created)"
  value       = var.enable_dashboard ? "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main[0].dashboard_name}" : null
}

#===============================================================================
# CloudWatch Agent IAM Outputs
#===============================================================================

output "cloudwatch_agent_role_arn" {
  description = "ARN of CloudWatch Agent IAM role (if created)"
  value       = var.enable_cloudwatch_agent ? aws_iam_role.cloudwatch_agent[0].arn : null
}

output "cloudwatch_agent_role_name" {
  description = "Name of CloudWatch Agent IAM role (if created)"
  value       = var.enable_cloudwatch_agent ? aws_iam_role.cloudwatch_agent[0].name : null
}

output "cloudwatch_agent_instance_profile_arn" {
  description = "ARN of CloudWatch Agent IAM instance profile (if created)"
  value       = var.enable_cloudwatch_agent ? aws_iam_instance_profile.cloudwatch_agent[0].arn : null
}

output "cloudwatch_agent_instance_profile_name" {
  description = "Name of CloudWatch Agent IAM instance profile (if created)"
  value       = var.enable_cloudwatch_agent ? aws_iam_instance_profile.cloudwatch_agent[0].name : null
}

#===============================================================================
# Configuration Summary Outputs
#===============================================================================

output "monitoring_configuration" {
  description = "Summary of monitoring configuration"
  value = {
    cpu_monitoring_enabled          = true
    memory_monitoring_enabled       = var.enable_memory_monitoring
    disk_monitoring_enabled         = var.enable_disk_monitoring
    status_check_monitoring_enabled = var.enable_status_checks
    dashboard_enabled               = var.enable_dashboard
    cloudwatch_agent_enabled        = var.enable_cloudwatch_agent
    log_groups_count                = length(aws_cloudwatch_log_group.application)
    alarm_emails_count              = length(var.alarm_emails)
    instances_monitored             = length(var.instance_ids)
    log_retention_days              = var.log_retention_days
  }
}

output "monitoring_endpoints" {
  description = "Useful endpoints for monitoring"
  value = {
    cloudwatch_console = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/"
    sns_console        = "https://${var.aws_region}.console.aws.amazon.com/sns/v2/home?region=${var.aws_region}#/topics"
    logs_console       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups"
  }
}
