# Monitoring Module

This module creates CloudWatch monitoring resources including log groups, metric alarms, and SNS topics.

## Features

- CloudWatch Log Groups
- CloudWatch Metric Alarms
- SNS Topics for notifications
- CloudWatch Dashboard (optional)
- Metric Filters

## Usage

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  project_name    = "myproject"
  environment     = "dev"
  instance_ids    = module.compute.instance_ids
  alarm_email     = "alerts@example.com"
  
  cpu_threshold   = 80
  enable_dashboard = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | >= 4.0 |

## Outputs

| Name | Description |
|------|-------------|
| log_group_names | List of log group names |
| sns_topic_arn | ARN of the SNS topic |
