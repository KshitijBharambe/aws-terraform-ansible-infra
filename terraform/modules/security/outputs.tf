# Security Module - Outputs

#===============================================================================
# Security Group Outputs
#===============================================================================

output "web_security_group_id" {
  description = "ID of the web tier security group"
  value       = aws_security_group.web.id
}

output "web_security_group_name" {
  description = "Name of the web tier security group"
  value       = aws_security_group.web.name
}

output "app_security_group_id" {
  description = "ID of the application tier security group"
  value       = aws_security_group.app.id
}

output "app_security_group_name" {
  description = "Name of the application tier security group"
  value       = aws_security_group.app.name
}

output "data_security_group_id" {
  description = "ID of the database tier security group"
  value       = aws_security_group.data.id
}

output "data_security_group_name" {
  description = "Name of the database tier security group"
  value       = aws_security_group.data.name
}

output "all_security_group_ids" {
  description = "List of all security group IDs"
  value = [
    aws_security_group.web.id,
    aws_security_group.app.id,
    aws_security_group.data.id
  ]
}

#===============================================================================
# IAM Outputs
#===============================================================================

output "instance_role_name" {
  description = "Name of the IAM role for EC2 instances"
  value       = aws_iam_role.instance_role.name
}

output "instance_role_arn" {
  description = "ARN of the IAM role for EC2 instances"
  value       = aws_iam_role.instance_role.arn
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.instance_profile.name
}

output "instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.instance_profile.arn
}

#===============================================================================
# KMS Outputs
#===============================================================================

output "kms_ebs_key_id" {
  description = "ID of the KMS key for EBS encryption"
  value       = var.enable_kms ? aws_kms_key.ebs[0].id : null
}

output "kms_ebs_key_arn" {
  description = "ARN of the KMS key for EBS encryption"
  value       = var.enable_kms ? aws_kms_key.ebs[0].arn : null
}

output "kms_s3_key_id" {
  description = "ID of the KMS key for S3 encryption"
  value       = var.enable_kms ? aws_kms_key.s3[0].id : null
}

output "kms_s3_key_arn" {
  description = "ARN of the KMS key for S3 encryption"
  value       = var.enable_kms ? aws_kms_key.s3[0].arn : null
}

#===============================================================================
# Configuration Outputs
#===============================================================================

output "ssh_enabled" {
  description = "Whether SSH access is enabled"
  value       = var.enable_ssh_access
}

output "ssh_port" {
  description = "SSH port configured"
  value       = var.ssh_port
}

output "cloudwatch_access_enabled" {
  description = "Whether CloudWatch access is enabled"
  value       = var.enable_cloudwatch_access
}

output "s3_access_enabled" {
  description = "Whether S3 access is enabled"
  value       = var.enable_s3_access
}

output "ssm_access_enabled" {
  description = "Whether Systems Manager access is enabled"
  value       = var.enable_ssm_access
}

output "kms_enabled" {
  description = "Whether KMS encryption is enabled"
  value       = var.enable_kms
}
