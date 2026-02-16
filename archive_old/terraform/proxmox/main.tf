# Proxmox VE - Terraform (provider bpg/proxmox)
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs
#
# Prérequis : Proxmox installé, utilisateur + API Token créés, ZFS/storage configurés (voir scripts/proxmox/setup-zfs.sh)

terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.93"
    }
  }
}

# Provider : auth via API Token (recommandé)
# Format api_token = "user@realm!tokenid:secret"
provider "proxmox" {
  endpoint  = var.pm_api_url
  api_token = "${var.pm_api_token_id}=${var.pm_api_token_secret}"
  insecure  = var.pm_insecure
}

# Test de connexion : lister les nœuds du cluster
data "proxmox_virtual_environment_nodes" "nodes" {}
