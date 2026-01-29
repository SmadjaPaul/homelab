# =============================================================================
# Cloudflare Tunnel Variables
# =============================================================================

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (found in dashboard URL or API)"
  type        = string
  sensitive   = true
  default     = ""  # Required only when enable_tunnel = true
}

variable "tunnel_secret" {
  description = "Cloudflare Tunnel secret (base64 encoded, 32+ bytes)"
  type        = string
  sensitive   = true
  default     = ""  # Generate with: openssl rand -base64 32
}

variable "allowed_emails" {
  description = "Email addresses allowed to access internal services via Cloudflare Access"
  type        = list(string)
  default     = ["smadjapaul02@gmail.com"]
}

# Feature flag to enable/disable tunnel (disabled until infra is ready)
variable "enable_tunnel" {
  description = "Enable Cloudflare Tunnel (set to true when infrastructure is ready)"
  type        = bool
  default     = false
}
