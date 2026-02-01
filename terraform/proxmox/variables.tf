# =============================================================================
# Proxmox Terraform Variables
# =============================================================================

variable "pm_api_url" {
  description = "Proxmox VE API URL (e.g. https://192.168.68.51:8006/)"
  type        = string
}

variable "pm_api_token_id" {
  description = "API Token ID (format: user@realm!tokenname, e.g. terraform-prov@pve!terraform)"
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  description = "API Token secret"
  type        = string
  sensitive   = true
}

variable "pm_insecure" {
  description = "Skip TLS verification (true for self-signed certs)"
  type        = bool
  default     = true
}

# Nœud Proxmox cible (pour les VMs/LXC)
variable "pm_node_name" {
  description = "Proxmox node name (e.g. pve, or first node from data source)"
  type        = string
  default     = null
}

# Datastores (à adapter après setup ZFS : tank-vm, tank-iso, etc.)
variable "pm_storage_vm" {
  description = "Storage ID for VM disks (e.g. local-lvm or tank-vm after ZFS setup)"
  type        = string
  default     = "local-lvm"
}

variable "pm_storage_iso" {
  description = "Storage ID for ISO/templates (e.g. local or tank-iso)"
  type        = string
  default     = "local"
}

# -----------------------------------------------------------------------------
# Talos VM IDs (Proxmox VM IDs, doivent être uniques sur le nœud)
# -----------------------------------------------------------------------------

variable "talos_dev_vm_id" {
  description = "Proxmox VM ID for talos-dev (DEV cluster single-node)"
  type        = number
  default     = 100
}

variable "talos_prod_cp_vm_id" {
  description = "Proxmox VM ID for talos-prod-cp (PROD control plane)"
  type        = number
  default     = 101
}

variable "talos_prod_worker_1_vm_id" {
  description = "Proxmox VM ID for talos-prod-worker-1 (PROD worker)"
  type        = number
  default     = 102
}

# -----------------------------------------------------------------------------
# Talos ISO (premier boot — CD-ROM)
# -----------------------------------------------------------------------------

variable "talos_iso_file" {
  description = "Filename of Talos ISO on pm_storage_iso (e.g. v1.12.2-metal-amd64.iso). Leave empty to skip CD-ROM."
  type        = string
  default     = ""
}
