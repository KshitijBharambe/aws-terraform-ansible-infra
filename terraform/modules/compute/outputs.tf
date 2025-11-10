# Compute Module - Outputs

#===============================================================================
# Instance Information
#===============================================================================

output "instance_ids" {
  description = "IDs of EC2 instances"
  value       = var.enable_auto_scaling ? [] : aws_instance.main[*].id
}

output "instance_private_ips" {
  description = "Private IP addresses of instances"
  value       = var.enable_auto_scaling ? [] : aws_instance.main[*].private_ip
}

output "instance_public_ips" {
  description = "Public IP addresses of instances (if assigned)"
  value       = var.enable_auto_scaling ? [] : aws_instance.main[*].public_ip
}

output "elastic_ips" {
  description = "Elastic IP addresses (if created)"
  value       = var.enable_eip ? aws_eip.instance[*].public_ip : []
}

output "instance_availability_zones" {
  description = "Availability zones where instances are deployed"
  value       = var.enable_auto_scaling ? [] : aws_instance.main[*].availability_zone
}

#===============================================================================
# Auto Scaling Group Information
#===============================================================================

output "auto_scaling_group_id" {
  description = "ID of the Auto Scaling Group"
  value       = var.enable_auto_scaling ? aws_autoscaling_group.main[0].id : null
}

output "auto_scaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = var.enable_auto_scaling ? aws_autoscaling_group.main[0].name : null
}

output "auto_scaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = var.enable_auto_scaling ? aws_autoscaling_group.main[0].arn : null
}

output "auto_scaling_min_size" {
  description = "Minimum size of the Auto Scaling Group"
  value       = var.enable_auto_scaling ? aws_autoscaling_group.main[0].min_size : 0
}

output "auto_scaling_max_size" {
  description = "Maximum size of the Auto Scaling Group"
  value       = var.enable_auto_scaling ? aws_autoscaling_group.main[0].max_size : 0
}

output "auto_scaling_desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  value       = var.enable_auto_scaling ? aws_autoscaling_group.main[0].desired_capacity : 0
}

#===============================================================================
# Launch Template Information
#===============================================================================

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.main.id
}

output "launch_template_arn" {
  description = "ARN of the launch template"
  value       = aws_launch_template.main.arn
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.main.latest_version
}



#===============================================================================
# Scaling Policy Information
#===============================================================================

output "scale_up_policy_arn" {
  description = "ARN of the scale up policy"
  value       = var.enable_auto_scaling ? aws_autoscaling_policy.scale_up[0].arn : null
}

output "scale_down_policy_arn" {
  description = "ARN of the scale down policy"
  value       = var.enable_auto_scaling ? aws_autoscaling_policy.scale_down[0].arn : null
}

#===============================================================================
# Summary Outputs
#===============================================================================

output "deployment_type" {
  description = "Type of deployment (auto_scaling or individual)"
  value       = var.enable_auto_scaling ? "auto_scaling" : "individual"
}

output "instance_count" {
  description = "Number of instances deployed or configured"
  value       = var.enable_auto_scaling ? var.desired_capacity : var.instance_count
}

output "instance_type" {
  description = "Instance type used"
  value       = var.instance_type
}

output "ami_id" {
  description = "AMI ID used for instances"
  value       = var.ami_id
}

output "subnet_ids_used" {
  description = "Subnet IDs where instances are deployed"
  value       = var.subnet_ids
}

output "security_group_ids" {
  description = "Security group IDs attached to instances"
  value       = var.security_group_ids
}

output "instance_arns" {
  description = "ARNs of EC2 instances"
  value       = var.enable_auto_scaling ? [] : aws_instance.main[*].arn
}
