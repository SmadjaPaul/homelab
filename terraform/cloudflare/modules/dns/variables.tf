# =============================================================================
# DNS module — variables
# =============================================================================

variable "zone_id" {
  type        = string
  description = "Cloudflare Zone ID"
}

variable "domain" {
  type        = string
  description = "Root domain (e.g. smadja.dev)"
}

variable "enable_tunnel" {
  type        = bool
  description = "DEPRECATED: Application DNS now managed by external-dns in Kubernetes"
  default     = true
}

variable "homelab_services" {
  type = map(object({
    subdomain   = string
    description = string
    internal    = bool
    user_facing = bool
    skip_dns    = optional(bool, false)
  }))
  description = "DEPRECATED: Application DNS now managed by external-dns in Kubernetes"
  default     = {}
}

variable "tunnel_id" {
  type        = string
  description = "DEPRECATED: Application DNS now managed by external-dns in Kubernetes"
  default     = ""
}

variable "oci_management_ip" {
  type        = string
  description = "OCI Management VM public IP (for stream record)"
  default     = ""
}

variable "create_root_record" {
  type        = bool
  description = "Create root domain A record (set to false if already exists manually)"
  default     = true
}

variable "enable_stream_record" {
  type        = bool
  description = "Create DNS record for stream.smadja.dev (Comet) - DNS only, no proxy"
  default     = false
}
