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
  }))
  description = "Services map; internal services get an Access app"
  default     = {}
}

variable "authentik_oidc_enabled" {
  type        = bool
  description = "Use Authentik as OIDC IdP for Access"
  default     = false
}

variable "authentik_oidc_client_id" {
  type      = string
  sensitive = true
  default   = ""
}

variable "authentik_oidc_client_secret" {
  type      = string
  sensitive = true
  default   = ""
}

variable "authentik_oidc_auth_url" {
  type    = string
  default = ""
}

variable "authentik_oidc_token_url" {
  type    = string
  default = ""
}

variable "authentik_oidc_certs_url" {
  type    = string
  default = ""
}

variable "allowed_emails" {
  type        = list(string)
  description = "Emails allowed when not using Authentik IdP (fallback policy)"
  default     = []
}

variable "skip_interstitial" {
  type        = bool
  description = "Skip the 'Choose identity provider' page (users go straight to Authentik or email). Set true when using a single IdP."
  default     = true
}
