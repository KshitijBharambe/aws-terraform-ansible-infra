# Load Balancer Module - Output Values

#===============================================================================
# Load Balancer Outputs
#===============================================================================

output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "load_balancer_canonical_hosted_zone_id" {
  description = "Canonical hosted zone ID of the load balancer"
  value       = aws_lb.main.canonical_hosted_zone_id
}

output "load_balancer_id" {
  description = "ID of the load balancer"
  value       = aws_lb.main.id
}

#===============================================================================
# Target Group Outputs
#===============================================================================

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.main.arn
}

output "target_group_name" {
  description = "Name of the target group"
  value       = aws_lb_target_group.main.name
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group"
  value       = aws_lb_target_group.main.arn_suffix
}

#===============================================================================
# Listener Outputs
#===============================================================================

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener (if created)"
  value       = length(aws_lb_listener.https) > 0 ? aws_lb_listener.https[0].arn : null
}

output "listener_rule_arns" {
  description = "ARNs of the listener rules"
  value       = aws_lb_listener_rule.priority[*].arn
}

#===============================================================================
# Connection Information
#===============================================================================

output "load_balancer_url" {
  description = "URL of the load balancer"
  value       = "http://${aws_lb.main.dns_name}"
}

output "load_balancer_https_url" {
  description = "HTTPS URL of the load balancer (if HTTPS enabled)"
  value       = var.enable_https ? "https://${aws_lb.main.dns_name}" : null
}

#===============================================================================
# Additional Information
#===============================================================================

output "vpc_id" {
  description = "VPC ID of the load balancer"
  value       = aws_lb.main.vpc_id
}

output "security_group_ids" {
  description = "Security group IDs attached to the load balancer"
  value       = aws_lb.main.security_groups
}

output "subnet_ids" {
  description = "Subnet IDs attached to the load balancer"
  value       = aws_lb.main.subnet_ids
}
