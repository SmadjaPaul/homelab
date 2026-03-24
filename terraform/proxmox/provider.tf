terraform {
  required_version = ">= 1.12"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.73.0"
    }
  }
}

# Default provider configuration
provider "proxmox" {
  endpoint = local.secrets.PROXMOX_ENDPOINT
  username = local.secrets.PROXMOX_USERNAME
  password = var.proxmox_password != "" ? var.proxmox_password : local.secrets.PROXMOX_PASSWORD
  api_token = var.proxmox_token != "" ? var.proxmox_token : null
  insecure = true
}

variable "proxmox_password" {
  description = "Proxmox password (set via TF_VAR_proxmox_password)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "proxmox_token" {
  description = "Proxmox API token (set via TF_VAR_proxmox_token)"
  type        = string
  sensitive   = true
  default     = ""
}

locals {
  secrets = var.local_secrets
}

variable "local_secrets" {
  description = "Local secrets configuration"
  type = object({
    PROXMOX_ENDPOINT     = string
    PROXMOX_USERNAME     = string
    PROXMOX_PASSWORD     = string
    PROXMOX_NODE         = string
    PROXMOX_FAST_STORAGE = string
    PROXMOX_DATA_STORAGE = string
    HOME_NETWORK_PREFIX  = string
    HOME_NETWORK_GATEWAY = string
    HOME_NETWORK_SUBNET  = string
    SSH_PUBLIC_KEY       = string
    ENABLE_OMNI          = string
    OMNI_VMID            = string
    OMNI_IP              = string
    OMNI_CORES           = string
    OMNI_MEMORY          = string
    OMNI_DISK            = string
    HOME_OPS_VMID        = string
    HOME_OPS_IP          = string
    HOME_OPS_CORES       = string
    HOME_OPS_MEMORY      = string
    HOME_OPS_DISK        = string
  })
  default = {
    PROXMOX_ENDPOINT     = "https://192.168.68.51:8006"
    PROXMOX_USERNAME     = "root@pam"
    PROXMOX_PASSWORD     = "" # Legacy field, using var.proxmox_password instead
    PROXMOX_NODE         = "tatouine"
    PROXMOX_FAST_STORAGE = "nvme-vm"
    PROXMOX_DATA_STORAGE = "tank-vm"
    HOME_NETWORK_PREFIX  = "192.168.68"
    HOME_NETWORK_GATEWAY = "192.168.68.1"
    HOME_NETWORK_SUBNET  = "24"
    SSH_PUBLIC_KEY       = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/P1sed84qIh6KJTGP9wFWJpDr8kxX718Fz3OJLUhwp smadjapaul02@gmail.com"
    ENABLE_OMNI          = "true"
    OMNI_VMID            = "100"
    OMNI_IP              = "192.168.68.200"
    OMNI_CORES           = "2"
    OMNI_MEMORY          = "4096"
    OMNI_DISK            = "50"
    HOME_OPS_VMID        = "300"
    HOME_OPS_IP          = "192.168.68.30"
    HOME_OPS_CORES       = "4"
    HOME_OPS_MEMORY      = "8192"
    HOME_OPS_DISK        = "100"
  }
}
