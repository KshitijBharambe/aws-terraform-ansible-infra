# AWS Terraform Outputs
# Exposes infrastructure details for use by other systems

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "availability_zones" {
  description = "List of availability zones"
  value       = module.vpc.availability_zones
}

# Security Outputs
output "web_security_group_id" {
  description = "ID of the web security group"
  value       = module.security.web_security_group_id
}

output "app_security_group_id" {
  description = "ID of the application security group"
  value       = module.security.app_security_group_id
}

output "data_security_group_id" {
  description = "ID of the data tier security group"
  value       = module.security.data_security_group_id
}

# Compute Outputs
output "web_server_instance_ids" {
  description = "List of web server instance IDs"
  value       = module.web_servers.instance_ids
}

output "web_server_public_ips" {
  description = "List of web server public IP addresses"
  value       = module.web_servers.instance_public_ips
}

output "web_server_private_ips" {
  description = "List of web server private IP addresses"
  value       = module.web_servers.instance_private_ips
}

output "app_server_instance_ids" {
  description = "List of application server instance IDs"
  value       = length(module.app_servers) > 0 ? module.app_servers[0].instance_ids : []
}

output "app_server_private_ips" {
  description = "List of application server private IP addresses"
  value       = length(module.app_servers) > 0 ? module.app_servers[0].instance_private_ips : []
}

output "all_instance_ids" {
  description = "List of all instance IDs"
  value = concat(
    module.web_servers.instance_ids,
    length(module.app_servers) > 0 ? module.app_servers[0].instance_ids : []
  )
}

output "all_instance_public_ips" {
  description = "List of all instance public IP addresses"
  value = concat(
    module.web_servers.instance_public_ips,
    length(module.app_servers) > 0 ? module.app_servers[0].instance_public_ips : []
  )
}

# Load Balancer Outputs
output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = var.enable_load_balancer ? module.loadbalancer[0].load_balancer_arn : null
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = var.enable_load_balancer ? module.loadbalancer[0].load_balancer_dns_name : null
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = var.enable_load_balancer ? module.loadbalancer[0].load_balancer_zone_id : null
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = var.enable_load_balancer ? module.loadbalancer[0].target_group_arn : null
}

# Monitoring Outputs
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.application.name
}

output "operations_sns_topic_arn" {
  description = "ARN of the operations SNS topic"
  value       = aws_sns_topic.operations.arn
}

# Backup Outputs
output "backup_vault_name" {
  description = "Name of the backup vault"
  value       = var.enable_backup ? aws_backup_vault.main[0].name : null
}

output "backup_plan_arn" {
  description = "ARN of the backup plan"
  value       = var.enable_backup ? aws_backup_plan.main[0].arn : null
}

# IAM Outputs
output "ssm_instance_profile_name" {
  description = "Name of the SSM instance profile"
  value       = aws_iam_instance_profile.ssm.name
}

output "ssm_role_arn" {
  description = "ARN of the SSM role"
  value       = aws_iam_role.ssm_role.arn
}

output "backup_role_arn" {
  description = "ARN of the backup role"
  value       = var.enable_backup ? aws_iam_role.backup_role[0].arn : null
}

# Cost Management Outputs
output "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  value       = var.monthly_budget_limit
}

output "cost_anomaly_monitor_arn" {
  description = "ARN of the cost anomaly monitor"
  value       = var.enable_cost_anomaly_detection ? aws_ce_anomaly_monitor.main[0].arn : null
}

# Terraform State Outputs
output "terraform_state_bucket_name" {
  description = "Name of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_bucket_arn" {
  description = "ARN of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "terraform_lock_table_name" {
  description = "Name of the Terraform lock table"
  value       = aws_dynamodb_table.terraform_lock.name
}

output "terraform_state_notifications_topic_arn" {
  description = "ARN of the Terraform state notifications SNS topic"
  value       = aws_sns_topic.terraform_state_notifications.arn
}

# Regional Information
output "aws_region" {
  description = "AWS region"
  value       = data.aws_region.current.name
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_caller_user_arn" {
  description = "ARN of the AWS caller"
  value       = data.aws_caller_identity.current.arn
}

# Connection Information
output "ssh_connection_command" {
  description = "SSH connection command template"
  value       = var.key_name != "" ? "ssh -i ${var.key_name}.pem ec2-user@{PUBLIC_IP}" : "SSH key not provided"
}

output "web_access_urls" {
  description = "URLs to access web services"
  value = {
    for idx, ip in module.web_servers.instance_public_ips :
    "web_server_${idx}" => ip != "" ? "http://${ip}" : "No public IP"
  }
}

output "load_balancer_url" {
  description = "URL to access the load balancer"
  value       = var.enable_load_balancer ? "http://${module.loadbalancer[0].load_balancer_dns_name}" : null
}

output "app_access_urls" {
  description = "URLs to access application services"
  value = length(module.app_servers) > 0 ? {
    for idx, ip in module.app_servers[0].instance_private_ips :
    "app_server_${idx}" => "http://${ip}:8080"
  } : {}
}

# Ansible Inventory Outputs
output "ansible_inventory" {
  description = "Ansible inventory configuration"
  value = {
    webservers = {
      hosts = {
        for idx, instance_id in module.web_servers.instance_ids :
        "web-${idx}" => {
          ansible_host                 = try(module.web_servers.instance_public_ips[idx], module.web_servers.instance_private_ips[idx])
          ansible_user                 = "ec2-user"
          ansible_ssh_private_key_file = "${var.key_name}.pem"
          ansible_python_interpreter   = "/usr/bin/python3"
        }
      }
    }
    appservers = length(module.app_servers) > 0 ? {
      hosts = {
        for idx, instance_id in module.app_servers[0].instance_ids :
        "app-${idx}" => {
          ansible_host                 = var.enable_nat_gateway ? module.app_servers[0].instance_private_ips[idx] : try(module.app_servers[0].instance_public_ips[idx], module.app_servers[0].instance_private_ips[idx])
          ansible_user                 = "ec2-user"
          ansible_ssh_private_key_file = "${var.key_name}.pem"
          ansible_python_interpreter   = "/usr/bin/python3"
        }
      }
    } : { hosts = {} }
    _meta = {
      hostvars = merge(
        {
          for idx, instance_id in module.web_servers.instance_ids :
          "web-${idx}" => {
            instance_id = instance_id
            private_ip  = module.web_servers.instance_private_ips[idx]
            public_ip   = try(module.web_servers.instance_public_ips[idx], "")
            role        = "webserver"
          }
        },
        length(module.app_servers) > 0 ? {
          for idx, instance_id in module.app_servers[0].instance_ids :
          "app-${idx}" => {
            instance_id = instance_id
            private_ip  = module.app_servers[0].instance_private_ips[idx]
            public_ip   = try(module.app_servers[0].instance_public_ips[idx], "")
            role        = "appserver"
          }
        } : {}
      )
    }
  }
}

# Summary Output
output "deployment_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    project_name       = var.project_name
    environment        = var.environment
    region             = var.aws_region
    vpc_id             = module.vpc.vpc_id
    web_servers        = length(module.web_servers)
    app_servers        = length(module.app_servers)
    load_balancer      = var.enable_load_balancer
    backup_enabled     = var.enable_backup
    monitoring_enabled = var.enable_cloudwatch_alarms
    cost_optimization = {
      nat_gateway    = var.enable_nat_gateway ? "enabled" : "disabled"
      savings_plans  = var.enable_savings_plans ? "enabled" : "disabled"
      spot_instances = var.enable_spot_instances ? "enabled" : "disabled"
    }
    deployment_time = timestamp()
  }
}
