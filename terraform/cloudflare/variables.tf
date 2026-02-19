# =============================================================================
# Cloudflare Variables
# =============================================================================

variable "doppler_token" {
  description = "Doppler API token for storing secrets"
  type        = string
  sensitive   = true
}

variable "doppler_project" {
  description = "Doppler project name"
  type        = string
  default     = "infrastructure"
}

variable "doppler_environment" {
  description = "Doppler environment (config)"
  type        = string
  default     = "prd"
}

# zone_id and domain are sourced from Doppler (locals.tf). Passed to child modules as local.zone_id / local.domain.

# Geo-restriction: allow traffic only from these countries (ISO 3166-1 Alpha 2)
# Empty list = no geo restriction (worldwide)
variable "allowed_countries" {
  description = "Allow access only from these country codes (e.g. [\"FR\"] for France only). Empty = no restriction."
  type        = list(string)
  default     = ["FR"]
}

# In CI we set enable_geo_restriction = false: a ruleset may already exist in Dashboard (create/import to manage via Terraform).
# Now sourced from Doppler: ENABLE_GEO_RESTRICTION

# Set to true to regenerate tunnel credentials (will update Doppler secrets)
variable "regenerate_tunnel_credentials" {
  description = "Set to true to regenerate tunnel credentials. Will update Doppler secrets with new values."
  type        = bool
  default     = false
}

# Access applications managed via enable_tunnel (no separate flag needed)

# Homelab service subdomains
variable "homelab_services" {
  description = "Homelab services to expose via Cloudflare Tunnel"
  type = map(object({
    subdomain   = string
    description = string
    internal    = bool
    user_facing = bool
  }))
  default = {
    # ===========================================
    # USER-FACING SERVICES (visible to users)
    # ===========================================
    homepage = {
      subdomain   = "home"
      description = "Homepage dashboard"
      internal    = false
      user_facing = true
    }
    authentik = {
      subdomain   = "auth"
      description = "Authentik SSO"
      internal    = false
      user_facing = true
    }

    # ===========================================
    # TECHNICAL SERVICES (admin only)
    # ===========================================
    grafana = {
      subdomain   = "grafana"
      description = "Grafana dashboards"
      internal    = true
      user_facing = false
    }
    proxmox = {
      subdomain   = "proxmox"
      description = "Proxmox VE management (at home)"
      internal    = true
      user_facing = false
    }
  }
}

# Oracle Cloud IPs (will be populated after VMs are created)
variable "oci_management_ip" {
  description = "OCI Management VM public IP (for stream record)"
  type        = string
  default     = ""
}

variable "oke_services" {
  description = "OKE services to expose via Cloudflare Tunnel (routed through traefik)"
  type = map(object({
    hostname = string
    service  = string
    port     = number
    internal = bool
  }))
  default = {
    authentik = {
      hostname = "auth"
      service  = "authentik-server"
      port     = 80
      internal = false
    }
    homepage = {
      hostname = "home"
      service  = "homepage"
      port     = 80
      internal = false
    }
    grafana = {
      hostname = "grafana"
      service  = "grafana"
      port     = 80
      internal = true
    }
  }
}

# Proxmox (local network, accessed via Tunnel)
variable "proxmox_local_ip" {
  description = "Proxmox local IP address"
  type        = string
  default     = "192.168.68.51"
}

# =============================================================================
# Tunnel
# =============================================================================
variable "allowed_emails" {
  description = "Emails allowed for Access when not using Authentik IdP"
  type        = list(string)
  default     = ["smadjapaul02@gmail.com", "smadja-paul@protonmail.com"]
}

variable "enable_tunnel" {
  description = "Enable Cloudflare Tunnel and Access"
  type        = bool
  default     = false
}

variable "enable_tunnel_config" {
  description = "Manage tunnel ingress config in Terraform. Set false if API returns 1002/1055 (Tunnel/Config not found)."
  type        = bool
  default     = false
}

# =============================================================================
# Authentik as OIDC IdP for Cloudflare Access
# =============================================================================
variable "authentik_oidc_enabled" {
  description = "Use Authentik as OIDC IdP for Access (users in Authentik get access)"
  type        = bool
  default     = false
}

variable "authentik_oidc_client_id" {
  description = "Authentik OAuth2 client_id for Cloudflare Access (from terraform/authentik output)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "authentik_oidc_client_secret" {
  description = "Authentik OAuth2 client_secret for Cloudflare Access"
  type        = string
  default     = ""
  sensitive   = true
}

variable "authentik_oidc_auth_url" {
  description = "Authentik OIDC authorization URL"
  type        = string
  default     = ""
}

variable "authentik_oidc_token_url" {
  description = "Authentik OIDC token URL"
  type        = string
  default     = ""
}

variable "authentik_oidc_certs_url" {
  description = "Authentik OIDC JWKS/certs URL"
  type        = string
  default     = ""
}

variable "access_skip_interstitial" {
  description = "Skip Cloudflare Access 'Choose identity provider' page (users go straight to Authentik or email)"
  type        = bool
  default     = true
}

# Set to false if root record already exists manually in Cloudflare dashboard
variable "create_root_record" {
  type        = bool
  description = "Create root domain A record (set to false if already exists manually)"
  default     = true
}

# Enable DNS record for stream.smadja.dev (Comet streaming service)
variable "enable_stream_record" {
  type        = bool
  description = "Create DNS record for stream.smadja.dev (Comet) - DNS only, points to OCI management IP"
  default     = false
}

# Enable Cloudflare cache rules for Comet
variable "enable_comet_cache_rules" {
  type        = bool
  description = "Enable Cloudflare cache rules for Comet streaming service (bypass cache for API, cache static assets)"
  default     = false
}
