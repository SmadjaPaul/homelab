# =============================================================================
# Oracle Cloud Infrastructure - OKE (Free Tier)
# Simple Kubernetes cluster without management VM
# =============================================================================

terraform {
  # Backend "oci" requires Terraform 1.11+
  required_version = ">= 1.11"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

provider "oci" {
  region = var.region
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
# OKE Module (Kubernetes Cluster - Free Tier)
# =============================================================================

module "oke" {
  source = "./modules/oke"

  compartment_id     = var.compartment_id
  cluster_name       = "homelab-k8s"
  vcn_id             = module.network.vcn_id
  lb_subnet_id       = module.network.public_subnet_id
  worker_subnet_id   = module.network.private_subnet_id
  kubernetes_version = var.kubernetes_version
  region             = var.region
  node_ocpus         = 2
  node_memory        = 12
  node_count         = 2
  ssh_public_key     = var.ssh_public_key

  tags = {
    Environment = "homelab"
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Monitoring & Logging Module (Free Tier)
# =============================================================================

module "monitoring" {
  source = "./modules/monitoring"

  compartment_id = var.compartment_id
  prefix         = "homelab"

  tags = {
    Environment = "homelab"
    ManagedBy   = "terraform"
  }
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

output "cluster_id" {
  value = module.oke.cluster_id
}

output "cluster_endpoint" {
  value = module.oke.cluster_endpoint
}

output "kubeconfig_command" {
  value = module.oke.kubeconfig_command
}

output "log_group_id" {
  value = module.monitoring.log_group_id
}
