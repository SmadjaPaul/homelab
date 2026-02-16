# =============================================================================
# Oracle Cloud Infrastructure - Homelab
# Modular architecture: Network, Compute, OKE, Object Storage
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0"
    }
  }
}

provider "oci" {
  region = var.region
}

# =============================================================================
# Variables
# =============================================================================

variable "region" {
  description = "OCI Region"
  type        = string
  default     = "eu-paris-1"
}

variable "tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for VMs"
  type        = string
  default     = ""
}

# =============================================================================
# Network Module
# =============================================================================

module "network" {
  source = "./modules/network"

  compartment_id      = var.compartment_id
  vcn_name            = "homelab"
  vcn_cidr            = "10.0.0.0/16"
  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"

  tags = {
    Environment = "homelab"
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Object Storage Module (for Terraform state)
# =============================================================================

module "object_storage" {
  source = "./modules/object-storage"

  compartment_id = var.compartment_id
  namespace      = var.oci_namespace
  bucket_name    = "terraform-states"

  tags = {
    Environment = "homelab"
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Compute Module (Management VM - Optional)
# =============================================================================

module "compute" {
  source = "./modules/compute"

  count = var.enable_management_vm ? 1 : 0

  compartment_id   = var.compartment_id
  vm_name          = "homelab-management"
  subnet_id        = module.network.public_subnet_id
  vm_ocpus         = 2
  vm_memory        = 12
  vm_disk          = 50
  ssh_public_key   = var.ssh_public_key
  assign_public_ip = true

  tags = {
    Environment = "homelab"
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# OKE Module (Kubernetes Cluster - Free Tier)
# =============================================================================

module "oke" {
  source = "./modules/oke"

  count = var.enable_oke ? 1 : 0

  compartment_id     = var.compartment_id
  cluster_name       = "homelab-oke"
  vcn_id             = module.network.vcn_id
  lb_subnet_id       = module.network.public_subnet_id
  worker_subnet_id   = module.network.private_subnet_id
  kubernetes_version = var.kubernetes_version
  region             = var.region
  node_ocpus         = 2
  node_memory        = 12
  node_count         = 2
  public_endpoint    = true

  tags = {
    Environment = "homelab"
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Configuration Flags
# =============================================================================

variable "enable_management_vm" {
  description = "Enable management VM"
  type        = bool
  default     = false
}

variable "enable_oke" {
  description = "Enable OKE cluster"
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.31.1"
}

variable "oci_namespace" {
  description = "OCI Object Storage namespace"
  type        = string
  default     = ""
}

# =============================================================================
# Outputs
# =============================================================================

output "vcn_id" {
  value = module.network.vcn_id
}

output "public_subnet_id" {
  value = module.network.public_subnet_id
}

output "private_subnet_id" {
  value = module.network.private_subnet_id
}

output "management_vm_ip" {
  value     = var.enable_management_vm ? module.compute[0].management_vm_ip : null
  sensitive = true
}

output "cluster_id" {
  value = var.enable_oke ? module.oke[0].cluster_id : null
}

output "cluster_endpoint" {
  value = var.enable_oke ? module.oke[0].cluster_endpoint : null
}

output "kubeconfig_command" {
  value = var.enable_oke ? module.oke[0].kubeconfig_command : null
}
