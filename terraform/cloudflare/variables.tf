# =============================================================================
# Cloudflare Variables
# =============================================================================

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone permissions"
  type        = string
  sensitive   = true
}

variable "zone_id" {
  description = "Cloudflare Zone ID for smadja.dev"
  type        = string
  default     = "bda8e2196f6b4f1684c6c9c06d996109"
}

variable "domain" {
  description = "Root domain"
  type        = string
  default     = "smadja.dev"

  validation {
    condition     = length(var.domain) > 0 && !endswith(var.domain, ".")
    error_message = "Domain must not be empty and must not end with a period."
  }
}

# Geo-restriction: allow traffic only from these countries (ISO 3166-1 Alpha 2)
# Empty list = no geo restriction (worldwide)
variable "allowed_countries" {
  description = "Allow access only from these country codes (e.g. [\"FR\"] for France only). Empty = no restriction."
  type        = list(string)
  default     = ["FR"]
}

# In CI we set enable_geo_restriction = false: a ruleset may already exist in Dashboard (create/import to manage via Terraform).
variable "enable_geo_restriction" {
  description = "Enable WAF rule to block traffic from countries not in allowed_countries. Set false in CI if the rule already exists in Dashboard."
  type        = bool
  default     = true
}

# Zone settings (SSL, HSTS, etc.). Set to false if API token lacks Zone Settings Edit (error 9109).
variable "enable_zone_settings" {
  description = "Manage zone security settings (SSL, HSTS, etc.). Set false if token lacks Zone Settings permission."
  type        = bool
  default     = false
}

# Reserved for future use: disable Access applications if token lacks Access: Apps and Policies.
variable "enable_access_applications" {
  description = "Reserved. Set false if token lacks Access permissions; currently Access apps are always managed when enable_tunnel is true."
  type        = bool
  default     = true
}

# Authentik API: skip Cloudflare challenge for /api/* so Terraform/CI can call the API.
# Set to true only if your API token has Zone → Configuration Rules → Edit.
# If not, leave false and create the rule once manually: see security.tf comment or docs.
variable "enable_authentik_api_skip_challenge" {
  description = "Create Configuration Rule to skip challenge for auth.*/api/* (requires token with Config/Configuration Rules permission; else create rule manually in dashboard)"
  type        = bool
  default     = false
}

# Homelab service subdomains
variable "homelab_services" {
  description = "Homelab services to expose via Cloudflare Tunnel"
  type = map(object({
    subdomain   = string
    description = string
    internal    = bool # true = requires Cloudflare Access, false = public
    user_facing = bool # true = visible to users, false = admin only
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
    status = {
      subdomain   = "status"
      description = "Uptime Kuma status page"
      internal    = false
      user_facing = true
    }
    feedback = {
      subdomain   = "feedback"
      description = "Fider feedback portal"
      internal    = false
      user_facing = true
    }
    docs = {
      subdomain   = "docs"
      description = "Docusaurus documentation"
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
    prometheus = {
      subdomain   = "prometheus"
      description = "Prometheus metrics"
      internal    = true
      user_facing = false
    }
    alertmanager = {
      subdomain   = "alerts"
      description = "Alertmanager"
      internal    = true
      user_facing = false
    }
    proxmox = {
      subdomain   = "proxmox"
      description = "Proxmox VE management"
      internal    = true
      user_facing = false
    }
    argocd = {
      subdomain   = "argocd"
      description = "ArgoCD GitOps"
      internal    = true
      user_facing = false
    }
    omni = {
      subdomain   = "omni"
      description = "Omni Talos management"
      internal    = true
      user_facing = false
    }
    litellm = {
      subdomain   = "llm"
      description = "LiteLLM proxy (Synthetic, Cline)"
      internal    = true
      user_facing = false
    }
    openclaw = {
      subdomain   = "openclaw"
      description = "OpenClaw personal AI gateway"
      internal    = true
      user_facing = false
    }
  }
}

# Oracle Cloud IPs (will be populated after VMs are created)
variable "oci_management_ip" {
  description = "OCI Management VM public IP"
  type        = string
  default     = "" # Will be set after VM creation
}

variable "oci_node_ips" {
  description = "OCI K8s node public IPs"
  type        = list(string)
  default     = [] # Will be set after VM creation
}

# Proxmox (local network, accessed via Tunnel)
variable "proxmox_local_ip" {
  description = "Proxmox local IP address"
  type        = string
  default     = "192.168.68.51"
}

# =============================================================================
# Tunnel (see also tunnel-related vars below)
# =============================================================================
variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (required when enable_tunnel = true)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tunnel_secret" {
  description = "Cloudflare Tunnel secret (base64, 32+ bytes). Generate: openssl rand -base64 32"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tunnel_id" {
  description = "Existing tunnel ID to use (if empty, will create new tunnel)"
  type        = string
  default     = ""
}

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
