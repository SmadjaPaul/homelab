# =============================================================================
# Tunnel module — variables
# =============================================================================

variable "account_id" {
  type        = string
  description = "Cloudflare Account ID"
}

variable "tunnel_secret" {
  type        = string
  sensitive   = true
  description = "Cloudflare Tunnel secret (base64, 32+ bytes)"
}

variable "domain" {
  type        = string
  description = "Root domain"
}

variable "proxmox_local_ip" {
  type        = string
  description = "Proxmox local IP for tunnel ingress"
  default     = "192.168.68.51"
}

# Set to false if tunnel config create/import fails (1002 Tunnel not found / 1055 Config not found).
variable "enable_tunnel_config" {
  type        = bool
  description = "Manage tunnel ingress config in Terraform. Set false to skip if API returns 1002/1055."
  default     = false
}
