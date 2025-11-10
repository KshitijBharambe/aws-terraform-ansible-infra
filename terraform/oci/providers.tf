# =============================================================================
# Oracle Cloud Infrastructure Provider Configuration
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

# OCI Provider Configuration
provider "oci" {
  region           = var.oci_region
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  
  # Optional: Use instance principal for compute instances
  # auth            = "InstancePrincipal"
  
  # Retry configuration
  retry {
    max_attempts = 10
    min_delay_ms = 1000
    max_delay_ms = 30000
  }
}

# OCI Provider for additional regions (multi-cloud setup)
provider "oci" {
  alias           = "secondary_region"
  region          = var.secondary_region
  tenancy_ocid    = var.tenancy_ocid
  user_ocid       = var.user_ocid
  fingerprint     = var.fingerprint
  private_key_path = var.private_key_path
}
