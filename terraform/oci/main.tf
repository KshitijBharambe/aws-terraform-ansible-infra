# =============================================================================
# Oracle Cloud Infrastructure Main Configuration
# =============================================================================

locals {
  # Common tags for all resources
  common_tags = merge(
    var.freeform_tags,
    {
      "Name"        = "${var.project_name}-${var.environment}"
      "Environment" = var.environment
      "ManagedBy"   = "Terraform"
    },
    var.defined_tags
  )
  
  # Availability domains for high availability
  availability_domains = [
    data.oci_identity_availability_domains.ads.availability_domains[0].name,
    data.oci_identity_availability_domains.ads.availability_domains[1].name
  ]
}

# =============================================================================
# Data Sources
# =============================================================================

# Get availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# Get latest Oracle Linux image
data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = var.instance_os
  operating_system_version = var.instance_os_version
  shape                   = var.instance_shape
  sort_by                 = "TIMECREATED"
  sort_order              = "DESC"
}

# Get current compartment
data "oci_identity_compartment" "current" {
  id = var.compartment_ocid
}

# =============================================================================
# Networking
# =============================================================================

# Virtual Cloud Network (VCN)
resource "oci_core_vcn" "main" {
  cidr_block     = var.vcn_cidr
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-vcn"
  dns_label      = replace(var.project_name, "-", "")
  
  freeform_tags = local.common_tags
  
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

# Internet Gateway
resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-igw"
  vcn_id         = oci_core_vcn.main.id
  
  freeform_tags = local.common_tags
}

# NAT Gateway (if enabled)
resource "oci_core_nat_gateway" "main" {
  count          = var.enable_nat_gateway ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-nat"
  vcn_id         = oci_core_vcn.main.id
  
  freeform_tags = local.common_tags
}

# Service Gateway (if enabled)
resource "oci_core_service_gateway" "main" {
  count          = var.enable_service_gateway ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-sgw"
  vcn_id         = oci_core_vcn.main.id
  
  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }
  
  freeform_tags = local.common_tags
}

data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
  }
}

# Route Table for Public Subnet
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-public-rt"
  vcn_id         = oci_core_vcn.main.id
  
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "INTERNET_GATEWAY"
    network_entity_id = oci_core_internet_gateway.main.id
  }
  
  freeform_tags = local.common_tags
}

# Route Table for Private Subnet
resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-private-rt"
  vcn_id         = oci_core_vcn.main.id
  
  dynamic "route_rules" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      destination       = "0.0.0.0/0"
      destination_type  = "NAT_GATEWAY"
      network_entity_id = oci_core_nat_gateway.main[0].id
    }
  }
  
  dynamic "route_rules" {
    for_each = var.enable_service_gateway ? [1] : []
    content {
      destination       = data.oci_core_services.all_services.services[0].cidr_block
      destination_type  = "SERVICE_GATEWAY"
      network_entity_id = oci_core_service_gateway.main[0].id
    }
  }
  
  freeform_tags = local.common_tags
}

# Security List for Public Subnet
resource "oci_core_security_list" "public" {
  count          = var.enable_security_lists ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-public-sl"
  vcn_id         = oci_core_vcn.main.id
  
  # Ingress rules
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    
    tcp_options {
      min = 22
      max = 22
    }
    description = "SSH"
  }
  
  dynamic "ingress_security_rules" {
    for_each = var.allowed_http_cidrs
    content {
      protocol = "6" # TCP
      source   = ingress_security_rules.value
      
      tcp_options {
        min = 80
        max = 80
      }
      description = "HTTP"
    }
  }
  
  dynamic "ingress_security_rules" {
    for_each = var.allowed_https_cidrs
    content {
      protocol = "6" # TCP
      source   = ingress_security_rules.value
      
      tcp_options {
        min = 443
        max = 443
      }
      description = "HTTPS"
    }
  }
  
  # Egress rules
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "All traffic"
  }
  
  freeform_tags = local.common_tags
}

# Security List for Private Subnet
resource "oci_core_security_list" "private" {
  count          = var.enable_security_lists ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-private-sl"
  vcn_id         = oci_core_vcn.main.id
  
  # Ingress rules - allow traffic from VCN
  ingress_security_rules {
    protocol    = "all"
    source      = var.vcn_cidr
    description = "All traffic from VCN"
  }
  
  # Egress rules
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "All traffic"
  }
  
  freeform_tags = local.common_tags
}

# Public Subnet
resource "oci_core_subnet" "public" {
  cidr_block          = var.public_subnet_cidr
  compartment_id      = var.compartment_ocid
  display_name        = "${var.project_name}-public-subnet"
  dns_label          = "public"
  vcn_id             = oci_core_vcn.main.id
  route_table_id     = oci_core_route_table.public.id
  security_list_ids  = var.enable_security_lists ? [oci_core_security_list.public[0].id] : []
  
  prohibit_public_ip_on_vnic = false
  
  freeform_tags = local.common_tags
}

# Private Subnet
resource "oci_core_subnet" "private" {
  cidr_block          = var.private_subnet_cidr
  compartment_id      = var.compartment_ocid
  display_name        = "${var.project_name}-private-subnet"
  dns_label          = "private"
  vcn_id             = oci_core_vcn.main.id
  route_table_id     = oci_core_route_table.private.id
  security_list_ids  = var.enable_security_lists ? [oci_core_security_list.private[0].id] : []
  
  prohibit_public_ip_on_vnic = true
  
  freeform_tags = local.common_tags
}

# =============================================================================
# Compute Instances
# =============================================================================

# Compute instances in public subnet (for web servers)
resource "oci_core_instance" "public_instances" {
  count               = var.use_free_tier ? 1 : 2
  availability_domain  = local.availability_domains[count.index % length(local.availability_domains)]
  compartment_id      = var.compartment_ocid
  display_name        = "${var.project_name}-web-${count.index + 1}"
  shape               = var.instance_shape
  
  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }
  
  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    hostname_label   = "web-${count.index + 1}"
  }
  
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data          = base64encode(templatefile("${path.module}/cloud-init/web-server.yml", {
      hostname = "web-${count.index + 1}"
      project  = var.project_name
    }))
  }
  
  shape_config {
    ocpus         = var.instance_shape == "VM.Standard.A1.Flex" ? 1 : null
    memory_in_gbs = var.instance_shape == "VM.Standard.A1.Flex" ? 6 : null
  }
  
  freeform_tags = merge(local.common_tags, {
    "Type" = "WebServer"
  })
  
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

# Compute instances in private subnet (for application servers)
resource "oci_core_instance" "private_instances" {
  count               = var.enable_nat_gateway ? (var.use_free_tier ? 1 : 2) : 0
  availability_domain  = local.availability_domains[count.index % length(local.availability_domains)]
  compartment_id      = var.compartment_ocid
  display_name        = "${var.project_name}-app-${count.index + 1}"
  shape               = var.instance_shape
  
  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }
  
  create_vnic_details {
    subnet_id        = oci_core_subnet.private.id
    assign_public_ip = false
    hostname_label   = "app-${count.index + 1}"
  }
  
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data          = base64encode(templatefile("${path.module}/cloud-init/app-server.yml", {
      hostname = "app-${count.index + 1}"
      project  = var.project_name
    }))
  }
  
  shape_config {
    ocpus         = var.instance_shape == "VM.Standard.A1.Flex" ? 1 : null
    memory_in_gbs = var.instance_shape == "VM.Standard.A1.Flex" ? 6 : null
  }
  
  freeform_tags = merge(local.common_tags, {
    "Type" = "AppServer"
  })
  
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

# =============================================================================
# Storage
# =============================================================================

# Block Volumes
resource "oci_core_volume" "data_volumes" {
  count               = var.use_free_tier ? 0 : 2
  availability_domain = local.availability_domains[count.index % length(local.availability_domains)]
  compartment_id     = var.compartment_ocid
  display_name       = "${var.project_name}-data-${count.index + 1}"
  size_in_gbs       = var.block_volume_size
  
  freeform_tags = merge(local.common_tags, {
    "Type" = "DataVolume"
  })
}

# Attach block volumes to instances
resource "oci_core_volume_attachment" "data_attachments" {
  count           = var.use_free_tier ? 0 : 2
  instance_id     = oci_core_instance.public_instances[count.index].id
  volume_id       = oci_core_volume.data_volumes[count.index].id
  attachment_type = "iscsi"
  
  device = "/dev/oracleoci/oraclevdb"
}

# =============================================================================
# Load Balancer
# =============================================================================

resource "oci_load_balancer_load_balancer" "main" {
  count          = var.use_free_tier ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-lb"
  shape          = var.load_balancer_shape
  
  subnet_ids = [
    oci_core_subnet.public.id
  ]
  
  dynamic "shape_details" {
    for_each = var.load_balancer_shape == "flexible" ? [1] : []
    content {
      minimum_bandwidth_in_mbps = 10
      maximum_bandwidth_in_mbps = var.load_balancer_bandwidth
    }
  }
  
  freeform_tags = merge(local.common_tags, {
    "Type" = "LoadBalancer"
  })
}

resource "oci_load_balancer_backend_set" "web" {
  count            = var.use_free_tier ? 0 : 1
  load_balancer_id = oci_load_balancer_load_balancer.main[0].id
  name             = "web-backend-set"
  policy           = "ROUND_ROBIN"
  
  health_checker {
    protocol          = "HTTP"
    port             = 80
    url_path         = "/health"
    return_code      = 200
    interval_ms      = 10000
    timeout_in_millis = 3000
    retries          = 3
  }
}

resource "oci_load_balancer_backend" "web" {
  count             = var.use_free_tier ? 0 : length(oci_core_instance.public_instances)
  load_balancer_id  = oci_load_balancer_load_balancer.main[0].id
  backendset_name   = oci_load_balancer_backend_set.web[0].name
  ip_address        = oci_core_instance.public_instances[count.index].private_ip
  port             = 80
  backup           = false
  drain           = false
  offline         = false
  weight          = 1
}

resource "oci_load_balancer_listener" "http" {
  count                    = var.use_free_tier ? 0 : 1
  load_balancer_id         = oci_load_balancer_load_balancer.main[0].id
  name                    = "http-listener"
  default_backend_set_name  = oci_load_balancer_backend_set.web[0].name
  port                    = 80
  protocol                = "HTTP"
  
  connection_configuration {
    idle_timeout_in_seconds = 300
  }
}

# =============================================================================
# Database (Optional - for production use)
# =============================================================================

resource "oci_database_db_system" "main" {
  count               = var.environment == "production" && !var.use_free_tier ? 1 : 0
  compartment_id      = var.compartment_ocid
  display_name        = "${var.project_name}-db"
  availability_domain = local.availability_domains[0]
  shape               = var.db_shape
  
  subnet_id           = oci_core_subnet.private.id
  ssh_public_keys     = [var.ssh_public_key]
  
  db_home {
    display_name = "${var.project_name}-db-home"
    database {
      admin_password = var.db_admin_password
      db_name       = "${var.project_name}db"
      db_workload  = "OLTP"
      pdb_name     = "${var.project_name}pdb"
    }
  }
  
  db_system_options {
    storage_management = "LVM"
  }
  
  backup_policy {
    is_enabled        = var.backup_enabled
    auto_backup_enabled = var.backup_enabled
    retention_period_in_days = var.backup_retention_days
  }
  
  freeform_tags = merge(local.common_tags, {
    "Type" = "Database"
  })
  
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

# =============================================================================
# Monitoring and Logging
# =============================================================================

# Monitoring for compute instances
resource "oci_monitoring_metric_alarm" "cpu_alarm" {
  count               = var.enable_monitoring ? length(oci_core_instance.public_instances) : 0
  compartment_id      = var.compartment_ocid
  display_name        = "${oci_core_instance.public_instances[count.index].display_name}-high-cpu"
  metric              = "CpuUtilization"
  namespace           = "oci_computeinstance"
  resource_group      = "${var.project_name}-${var.environment}"
  
  # Query for CPU utilization > 80%
  query              = "CpuUtilization[1m].mean() > 80"
  
  # Alarm dimensions
  dimensions = {
    resourceId = oci_core_instance.public_instances[count.index].id
  }
  
  # Notification
  alarm_actions = var.enable_notifications ? [oci_ons_notification_topic.main[0].topic_endpoint] : []
  
  # Severity and message
  severity          = "CRITICAL"
  body             = "CPU utilization is above 80% for ${oci_core_instance.public_instances[count.index].display_name}"
  
  is_enabled       = true
  resolution       = "1m"
  pending_duration = "PT5M"
  
  freeform_tags = local.common_tags
}

# Notification Topic
resource "oci_ons_notification_topic" "main" {
  count          = var.enable_notifications ? 1 : 0
  compartment_id = var.compartment_ocid
  name           = "${var.project_name}-notifications"
  description    = "Notifications for ${var.project_name} infrastructure"
  
  freeform_tags = local.common_tags
}

# Subscription for email notifications
resource "oci_ons_subscription" "email" {
  count          = var.enable_notifications && var.notification_email != "" ? 1 : 0
  topic_id      = oci_ons_notification_topic.main[0].id
  protocol      = "EMAIL"
  endpoint      = var.notification_email
}

# =============================================================================
# Security
# =============================================================================

# IAM policies for compute instances (if needed)
resource "oci_identity_policy" "compute_policy" {
  count          = var.environment == "production" ? 1 : 0
  compartment_id = var.compartment_ocid
  description    = "Policy for ${var.project_name} compute instances"
  name           = "${var.project_name}-compute-policy"
  statements = [
    "Allow group ${var.project_name}-administrators to manage all-resources in compartment ${data.oci_identity_compartment.current.name}",
    "Allow dynamic-group ${var.project_name}-instances to use metrics in compartment ${data.oci_identity_compartment.current.name}",
    "Allow dynamic-group ${var.project_name}-instances to read objectstorage-namespaces in compartment ${data.oci_identity_compartment.current.name}"
  ]
  
  freeform_tags = local.common_tags
}

# Dynamic Group for compute instances
resource "oci_identity_dynamic_group" "compute_instances" {
  count               = var.environment == "production" ? 1 : 0
  compartment_id      = var.compartment_ocid
  description         = "Dynamic group for ${var.project_name} compute instances"
  name                = "${var.project_name}-instances"
  matching_rule       = "ALL {instance.id, '${join("', '", oci_core_instance.public_instances[*].id)}'}"
}
