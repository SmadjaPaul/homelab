# =============================================================================
# Cloudflare Access — Authentik as OIDC Identity Provider
# =============================================================================
# When enabled, users who can log in to Authentik are allowed through
# Cloudflare Access without maintaining a separate allowed_emails list.
#
# Prerequisites:
# 1. In terraform/authentik: apply and get output cloudflare_access_oidc
# 2. Set authentik_oidc_* variables (or pass from Authentik outputs)
# 3. enable_tunnel = true and cloudflare_account_id set
#
# Docs: https://docs.goauthentik.io/integrations/services/cloudflare-access/
# =============================================================================

variable "authentik_oidc_enabled" {
  description = "Use Authentik as OIDC IdP for Cloudflare Access (users in Authentik get access)"
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
  description = "Authentik OIDC authorization URL (e.g. https://auth.example.com/application/o/authorize/)"
  type        = string
  default     = ""
}

variable "authentik_oidc_token_url" {
  description = "Authentik OIDC token URL"
  type        = string
  default     = ""
}

variable "authentik_oidc_certs_url" {
  description = "Authentik OIDC JWKS/certs URL (Certificate URL in Cloudflare)"
  type        = string
  default     = ""
}

# Identity provider: Authentik (OIDC)
resource "cloudflare_zero_trust_access_identity_provider" "authentik" {
  count = var.enable_tunnel && var.authentik_oidc_enabled && length(var.authentik_oidc_client_id) > 0 ? 1 : 0

  account_id = var.cloudflare_account_id
  name       = "Authentik"
  type       = "oidc"

  config {
    api_token     = false
    auth_url      = var.authentik_oidc_auth_url
    certs_url     = var.authentik_oidc_certs_url
    client_id     = var.authentik_oidc_client_id
    client_secret = var.authentik_oidc_client_secret
    token_url     = var.authentik_oidc_token_url
    pkce_enabled  = true
  }
}

# Policy: allow everyone who authenticated via Authentik
# Precedence 0 = evaluated first; any user who logged in through Authentik is allowed
resource "cloudflare_zero_trust_access_policy" "authentik_everyone" {
  for_each = var.enable_tunnel && var.authentik_oidc_enabled ? { for k, v in var.homelab_services : k => v if v.internal } : {}

  zone_id        = var.zone_id
  application_id = cloudflare_zero_trust_access_application.internal_services[each.key].id
  name           = "Allow Authentik users"
  precedence     = 0
  decision       = "allow"

  include {
    everyone = true
  }
}
