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
  description = "When true, CNAMEs point to tunnel; when false, placeholder A records for services"
}

variable "homelab_services" {
  type = map(object({
    subdomain   = string
    description = string
    internal    = bool
    user_facing = bool
  }))
  description = "Map of service key -> { subdomain, description, internal, user_facing }"
  default     = {}
}

# NOTE: OKE services DNS is managed by external-dns in Kubernetes.

variable "tunnel_id" {
  type        = string
  description = "Cloudflare Tunnel ID (for CNAME target). Empty when enable_tunnel = false."
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
