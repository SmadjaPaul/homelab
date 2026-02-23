# =============================================================================
# Access module — Zero Trust IdP, applications, policies
# =============================================================================

variable "account_id" {
  type        = string
  description = "Cloudflare Account ID"
}

variable "domain" {
  type        = string
  description = "Root domain"
}

variable "homelab_services" {
  type = map(object({
    subdomain   = string
    description = string
    internal    = bool
    user_facing = bool
    skip_dns    = optional(bool, false)
  }))
  description = "Services map; internal services get an Access app"
  default     = {}
}

variable "allowed_emails" {
  type        = list(string)
  description = "Emails allowed for Access (fallback policy)"
  default     = []
}

variable "skip_interstitial" {
  type        = bool
  description = "Skip the 'Choose identity provider' page (users go straight to Auth0). Set true when using a single IdP."
  default     = true
}

variable "bypass_ips" {
  type        = list(string)
  description = "IP addresses to bypass Cloudflare Access (for Terraform/API access)"
  default     = []
}

# =============================================================================
# Role-Based Access Control
# =============================================================================
variable "role_access" {
  type        = map(list(string))
  description = "Map of service keys to list of roles allowed access (e.g., { grafana = [\"admin\"], homepage = [\"admin\", \"family\"] })"
  default     = {}
}

# =============================================================================
# Auth0 OIDC IdP
# =============================================================================
variable "auth0_oidc_enabled" {
  type        = bool
  description = "Use Auth0 as OIDC IdP for Access"
  default     = false
}

variable "auth0_oidc_client_id" {
  type      = string
  sensitive = true
  default   = ""
}

variable "auth0_oidc_client_secret" {
  type      = string
  sensitive = true
  default   = ""
}

variable "auth0_domain" {
  type        = string
  description = "Auth0 domain (e.g., smadja.us.auth0.com)"
  default     = ""
}
