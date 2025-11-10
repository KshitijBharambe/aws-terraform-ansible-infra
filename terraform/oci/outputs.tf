# =============================================================================
# Oracle Cloud Infrastructure Outputs
# =============================================================================

output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.main.id
}

output "vcn_cidr" {
  description = "CIDR block of the VCN"
  value       = oci_core_vcn.main.cidr_block
}

output "public_subnet_id" {
  description = "OCID of the public subnet"
  value       = oci_core_subnet.public.id
}

output "private_subnet_id" {
  description = "OCID of the private subnet"
  value       = oci_core_subnet.private.id
}

output "public_instance_ids" {
  description = "OCIDs of public compute instances"
  value       = oci_core_instance.public_instances[*].id
}

output "public_instance_public_ips" {
  description = "Public IP addresses of public instances"
  value       = oci_core_instance.public_instances[*].public_ip
}

output "public_instance_private_ips" {
  description = "Private IP addresses of public instances"
  value       = oci_core_instance.public_instances[*].private_ip
}

output "private_instance_ids" {
  description = "OCIDs of private compute instances"
  value       = oci_core_instance.private_instances[*].id
}

output "private_instance_private_ips" {
  description = "Private IP addresses of private instances"
  value       = oci_core_instance.private_instances[*].private_ip
}

output "load_balancer_id" {
  description = "OCID of the load balancer"
  value       = length(oci_load_balancer_load_balancer.main) > 0 ? oci_load_balancer_load_balancer.main[0].id : null
}

output "load_balancer_ip" {
  description = "IP address of the load balancer"
  value       = length(oci_load_balancer_load_balancer.main) > 0 ? oci_load_balancer_load_balancer.main[0].ip_address_details[0].ip_address : null
}

output "load_balancer_hostname" {
  description = "Hostname of the load balancer"
  value       = length(oci_load_balancer_load_balancer.main) > 0 ? oci_load_balancer_load_balancer.main[0].ip_address_details[0].hostname : null
}

output "database_id" {
  description = "OCID of the database"
  value       = length(oci_database_db_system.main) > 0 ? oci_database_db_system.main[0].id : null
}

output "database_connection_string" {
  description = "Connection string for the database"
  value       = length(oci_database_db_system.main) > 0 ? "${oci_database_db_system.main[0].db_home[0].database[0].db_name}_${oci_database_db_system.main[0].db_home[0].database[0].pdb_name}.${oci_database_db_system.main[0].hostname}:${oci_database_db_system.main[0].port}" : null
  sensitive   = true
}

output "block_volume_ids" {
  description = "OCIDs of block volumes"
  value       = oci_core_volume.data_volumes[*].id
}

output "notification_topic_id" {
  description = "OCID of the notification topic"
  value       = length(oci_ons_notification_topic.main) > 0 ? oci_ons_notification_topic.main[0].id : null
}

output "internet_gateway_id" {
  description = "OCID of the internet gateway"
  value       = oci_core_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "OCID of the NAT gateway"
  value       = var.enable_nat_gateway ? oci_core_nat_gateway.main[0].id : null
}

output "service_gateway_id" {
  description = "OCID of the service gateway"
  value       = var.enable_service_gateway ? oci_core_service_gateway.main[0].id : null
}

output "availability_domains" {
  description = "List of availability domains"
  value       = local.availability_domains
}

output "compartment_id" {
  description = "OCID of the compartment"
  value       = var.compartment_ocid
}

output "region" {
  description = "OCI region"
  value       = var.oci_region
}

# SSH Access Information
output "ssh_command_public" {
  description = "SSH command for public instances"
  value       = formatlist("ssh -i %s opc@%s", var.ssh_private_key_path, oci_core_instance.public_instances[*].public_ip)
}

output "ssh_command_private" {
  description = "SSH command for private instances (requires bastion)"
  value       = length(oci_core_instance.private_instances) > 0 ? formatlist("ssh -i %s -J opc@%s opc@%s", var.ssh_private_key_path, oci_core_instance.public_instances[0].public_ip, oci_core_instance.private_instances[*].private_ip) : []
  sensitive   = true
}

# Cost Information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost in USD"
  value       = {
    compute      = var.use_free_tier ? 0.0 : (length(oci_core_instance.public_instances) + length(oci_core_instance.private_instances)) * 0.05
    storage      = var.use_free_tier ? 0.0 : length(oci_core_volume.data_volumes) * var.block_volume_size * 0.0025
    load_balancer = var.use_free_tier ? 0.0 : length(oci_load_balancer_load_balancer.main) * (var.load_balancer_shape == "flexible" ? var.load_balancer_bandwidth * 0.0025 : 0.025)
    database     = length(oci_database_db_system.main) > 0 ? 0.3 : 0.0
    total        = var.use_free_tier ? 0.0 : ((length(oci_core_instance.public_instances) + length(oci_core_instance.private_instances)) * 0.05) + (length(oci_core_volume.data_volumes) * var.block_volume_size * 0.0025) + (length(oci_load_balancer_load_balancer.main) > 0 ? (var.load_balancer_shape == "flexible" ? var.load_balancer_bandwidth * 0.0025 : 0.025) : 0.0) + (length(oci_database_db_system.main) > 0 ? 0.3 : 0.0)
  }
}

output "free_tier_usage" {
  description = "Free tier resource usage summary"
  value = {
    compute_instances_used   = length(oci_core_instance.public_instances) + length(oci_core_instance.private_instances)
    compute_instances_limit = var.use_free_tier ? 2 : 10
    block_volumes_used     = length(oci_core_volume.data_volumes)
    block_volumes_limit    = var.use_free_tier ? 0 : 200
    load_balancers_used    = length(oci_load_balancer_load_balancer.main)
    load_balancers_limit   = var.use_free_tier ? 0 : 10
    databases_used        = length(oci_database_db_system.main)
    databases_limit       = var.use_free_tier ? 0 : 2
    bandwidth_used        = var.load_balancer_shape == "flexible" ? var.load_balancer_bandwidth : 0
    bandwidth_limit       = var.use_free_tier ? 0 : 10000
  }
}

# Security Information
output "security_configuration" {
  description = "Security configuration summary"
  value = {
    security_lists_enabled = var.enable_security_lists
    nat_gateway_enabled   = var.enable_nat_gateway
    service_gateway_enabled = var.enable_service_gateway
    allowed_ssh_cidrs    = var.allowed_ssh_cidrs
    allowed_http_cidrs   = var.allowed_http_cidrs
    allowed_https_cidrs  = var.allowed_https_cidrs
    monitoring_enabled   = var.enable_monitoring
    notifications_enabled = var.enable_notifications
  }
}

# Network Information
output "network_information" {
  description = "Network configuration summary"
  value = {
    vcn_cidr              = var.vcn_cidr
    public_subnet_cidr      = var.public_subnet_cidr
    private_subnet_cidr     = var.private_subnet_cidr
    internet_gateway        = "Enabled"
    nat_gateway           = var.enable_nat_gateway ? "Enabled" : "Disabled"
    service_gateway       = var.enable_service_gateway ? "Enabled" : "Disabled"
    dns_label            = replace(var.project_name, "-", "")
    availability_domains  = length(local.availability_domains)
  }
}

# Access URLs
output "access_urls" {
  description = "Access URLs for deployed services"
  value = {
    load_balancer_http  = length(oci_load_balancer_load_balancer.main) > 0 ? "http://${oci_load_balancer_load_balancer.main[0].ip_address_details[0].ip_address}" : null
    load_balancer_https = length(oci_load_balancer_load_balancer.main) > 0 ? "https://${oci_load_balancer_load_balancer.main[0].ip_address_details[0].ip_address}" : null
    web_servers        = formatlist("http://%s", oci_core_instance.public_instances[*].public_ip)
  }
}

# Backup Information
output "backup_configuration" {
  description = "Backup configuration summary"
  value = {
    backup_enabled           = var.backup_enabled
    backup_retention_days    = var.backup_retention_days
    auto_backup_enabled     = length(oci_database_db_system.main) > 0 ? var.backup_enabled : false
    volume_backup_enabled    = length(oci_core_volume.data_volumes) > 0 ? var.backup_enabled : false
  }
}

# Monitoring Information
output "monitoring_configuration" {
  description = "Monitoring configuration summary"
  value = {
    monitoring_enabled        = var.enable_monitoring
    cpu_alarms_configured  = length(oci_monitoring_metric_alarm.cpu_alarm)
    notifications_enabled    = var.enable_notifications
    alarm_topic_id         = length(oci_ons_notification_topic.main) > 0 ? oci_ons_notification_topic.main[0].id : null
    email_subscriptions    = length(oci_ons_subscription.email)
  }
}

# Disaster Recovery Information
output "disaster_recovery_configuration" {
  description = "Disaster recovery configuration"
  value = {
    dr_enabled               = var.enable_dr
    secondary_region          = var.secondary_region
    replication_frequency     = var.dr_replication_frequency
    failover_test_enabled    = var.dr_failover_test_enabled
  }
}

# Tags Information
output "applied_tags" {
  description = "Tags applied to resources"
  value       = local.common_tags
}

# Terraform Information
output "terraform_configuration" {
  description = "Terraform configuration summary"
  value = {
    terraform_version       = ">= 1.5.0"
    oci_provider_version   = "~> 5.0"
    backend_configured    = false
    state_file_location   = "Local"
    workspace           = "default"
  }
}
