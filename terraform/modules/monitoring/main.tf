# Monitoring Module - Main Resources

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    var.tags,
    {
      Module      = "monitoring"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )

  # Create alarm for each instance if instance_ids provided
  instance_count = length(var.instance_ids)
}

#===============================================================================
# CloudWatch Log Groups
#===============================================================================

resource "aws_cloudwatch_log_group" "application" {
  count = length(var.log_groups) > 0 ? length(var.log_groups) : 1

  name              = local.instance_count > 0 ? "/aws/ec2/${var.instance_ids[count.index % local.instance_count]}/${var.log_groups[count.index % length(var.log_groups)]}" : "/aws/${local.name_prefix}/${var.log_groups[count.index % length(var.log_groups)]}"
  retention_in_days = var.log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-log-group-${count.index + 1}"
      Type = var.log_groups[count.index % length(var.log_groups)]
    }
  )
}

resource "aws_cloudwatch_log_group" "system" {
  count = var.enable_system_logs ? 1 : 0

  name              = "/aws/${local.name_prefix}/system"
  retention_in_days = var.log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-system-logs"
      Type = "System"
    }
  )
}

#===============================================================================
# SNS Topic for Notifications
#===============================================================================

resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alerts-topic"
    }
  )
}

resource "aws_sns_topic_subscription" "email" {
  count = length(var.alarm_emails) > 0 ? length(var.alarm_emails) : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_emails[count.index]
}

#===============================================================================
# CloudWatch Metric Alarms - CPU Utilization
#===============================================================================

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = local.instance_count

  alarm_name          = "${local.name_prefix}-cpu-high-${var.instance_ids[count.index]}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cpu_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.cpu_period
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "This metric monitors ec2 cpu utilization"
  treat_missing_data  = "notBreaching"
  dimensions = {
    InstanceId = var.instance_ids[count.index]
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-cpu-alarm-${var.instance_ids[count.index]}"
      Type     = "CPU"
      Instance = var.instance_ids[count.index]
    }
  )
}

#===============================================================================
# CloudWatch Metric Alarms - Memory Utilization (if enabled)
#===============================================================================

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  count = var.enable_memory_monitoring && local.instance_count > 0 ? local.instance_count : 0

  alarm_name          = "${local.name_prefix}-memory-high-${var.instance_ids[count.index]}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.memory_evaluation_periods
  metric_name         = "MemoryUtilization"
  namespace           = "CWAgent"
  period              = var.memory_period
  statistic           = "Average"
  threshold           = var.memory_threshold
  alarm_description   = "This metric monitors ec2 memory utilization"
  treat_missing_data  = "notBreaching"
  dimensions = {
    InstanceId = var.instance_ids[count.index]
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-memory-alarm-${var.instance_ids[count.index]}"
      Type     = "Memory"
      Instance = var.instance_ids[count.index]
    }
  )
}

#===============================================================================
# CloudWatch Metric Alarms - Disk Utilization (if enabled)
#===============================================================================

resource "aws_cloudwatch_metric_alarm" "disk_high" {
  count = var.enable_disk_monitoring && local.instance_count > 0 ? local.instance_count : 0

  alarm_name          = "${local.name_prefix}-disk-high-${var.instance_ids[count.index]}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.disk_evaluation_periods
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = var.disk_period
  statistic           = "Average"
  threshold           = var.disk_threshold
  alarm_description   = "This metric monitors ec2 disk utilization"
  treat_missing_data  = "notBreaching"
  dimensions = {
    InstanceId = var.instance_ids[count.index]
    path       = "/"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-disk-alarm-${var.instance_ids[count.index]}"
      Type     = "Disk"
      Instance = var.instance_ids[count.index]
    }
  )
}

#===============================================================================
# CloudWatch Metric Alarms - Status Check Failed
#===============================================================================

resource "aws_cloudwatch_metric_alarm" "status_check_failed" {
  count = var.enable_status_checks && local.instance_count > 0 ? local.instance_count : 0

  alarm_name          = "${local.name_prefix}-status-check-failed-${var.instance_ids[count.index]}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.status_check_evaluation_periods
  metric_name         = "StatusCheckFailed_System"
  namespace           = "AWS/EC2"
  period              = var.status_check_period
  statistic           = "Sum"
  threshold           = var.status_check_threshold
  alarm_description   = "This metric monitors ec2 status check failures"
  treat_missing_data  = "notBreaching"
  dimensions = {
    InstanceId = var.instance_ids[count.index]
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-status-alarm-${var.instance_ids[count.index]}"
      Type     = "StatusCheck"
      Instance = var.instance_ids[count.index]
    }
  )
}

#===============================================================================
# CloudWatch Dashboard (if enabled)
#===============================================================================

resource "aws_cloudwatch_dashboard" "main" {
  count = var.enable_dashboard ? 1 : 0

  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            for i in range(local.instance_count) : [
              "AWS/EC2", "CPUUtilization", "InstanceId", var.instance_ids[i]
            ]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "EC2 CPU Utilization"
          view   = "timeSeries"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          query  = "fields @timestamp, @message | sort @timestamp desc | limit 100"
          region = var.aws_region
          title  = "Recent Log Events"
          view   = "table"
        }
      }
    ]
  })
}

#===============================================================================
# IAM Role and Policy for CloudWatch Agent (if enabled)
#===============================================================================

resource "aws_iam_role" "cloudwatch_agent" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  name = "${local.name_prefix}-cloudwatch-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "cloudwatch_agent" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  name = "${local.name_prefix}-cloudwatch-agent-policy"
  role = aws_iam_role.cloudwatch_agent[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:CreateLogGroup",
          "logs:CreateLogStream"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "cloudwatch_agent" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  name = "${local.name_prefix}-cloudwatch-agent-profile"
  role = aws_iam_role.cloudwatch_agent[0].name
}
