# Output values for LocalStack infrastructure

output "test_bucket_name" {
  description = "Name of test S3 bucket"
  value       = var.create_test_resources ? aws_s3_bucket.test[0].id : null
}

output "test_table_name" {
  description = "Name of test DynamoDB table"
  value       = var.create_test_resources ? aws_dynamodb_table.test[0].id : null
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "web_security_group_id" {
  description = "Web security group ID"
  value       = module.security.web_security_group_id
}

output "app_security_group_id" {
  description = "App security group ID"
  value       = module.security.app_security_group_id
}

output "web_instance_ids" {
  description = "Web instance IDs"
  value       = module.web_servers.instance_ids
}

output "app_instance_ids" {
  description = "App instance IDs"
  value       = var.enable_app_tier ? module.app_servers[0].instance_ids : []
}

output "load_balancer_dns" {
  description = "Load balancer DNS name"
  value       = var.enable_load_balancer ? module.loadbalancer[0].load_balancer_dns : null
}

output "environment" {
  description = "Current environment"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}
