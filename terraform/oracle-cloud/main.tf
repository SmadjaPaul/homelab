# Oracle Cloud Infrastructure - Homelab
# This configuration creates the management and Kubernetes infrastructure
# on Oracle Cloud Always Free tier

terraform {
  # Backend "oci" requires Terraform 1.11+
  required_version = ">= 1.11"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.0"
    }
  }
}

# Provider configuration - uses ~/.oci/config by default
provider "oci" {
  region = var.region
}

# Data sources
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}
