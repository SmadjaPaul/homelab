# =============================================================================
# Cloudflare Access — Authentik IdP, applications, policies
# =============================================================================

locals {
  authentik_base  = "https://auth.${var.domain}"
  authentik_auth  = var.authentik_oidc_auth_url != "" ? var.authentik_oidc_auth_url : "${local.authentik_base}/application/o/authorize/"
  authentik_token = var.authentik_oidc_token_url != "" ? var.authentik_oidc_token_url : "${local.authentik_base}/application/o/token/"
  authentik_certs = var.authentik_oidc_certs_url != "" ? var.authentik_oidc_certs_url : "${local.authentik_base}/application/o/jwks/"
  internal_keys   = sort(keys({ for k, v in var.homelab_services : k => v if v.internal }))
}

# IdP: Authentik (OIDC)
resource "cloudflare_zero_trust_access_identity_provider" "authentik" {
  count = var.authentik_oidc_enabled && length(var.authentik_oidc_client_id) > 0 ? 1 : 0

  account_id = var.account_id
  name       = "Authentik"
  type       = "oidc"

  config {
    api_token     = false
    auth_url      = local.authentik_auth
    certs_url     = local.authentik_certs
    client_id     = var.authentik_oidc_client_id
    client_secret = var.authentik_oidc_client_secret
    token_url     = local.authentik_token
    pkce_enabled  = true
    scopes        = ["openid", "email", "profile"]
  }
}

# Access applications (internal services only)
resource "cloudflare_zero_trust_access_application" "internal_services" {
  for_each = { for k, v in var.homelab_services : k => v if v.internal }

  account_id       = var.account_id
  name             = "Homelab - ${each.value.description}"
  domain           = "${each.value.subdomain}.${var.domain}"
  type             = "self_hosted"
  session_duration = "24h"

  auto_redirect_to_identity = true
  allowed_idps              = (var.authentik_oidc_enabled && length(cloudflare_zero_trust_access_identity_provider.authentik) > 0) ? [cloudflare_zero_trust_access_identity_provider.authentik[0].id] : []
  skip_interstitial         = var.skip_interstitial
  options_preflight_bypass  = true
}

# Policy: allow everyone who authenticated via Authentik
resource "cloudflare_zero_trust_access_policy" "authentik_everyone" {
  for_each = var.authentik_oidc_enabled ? { for k, v in var.homelab_services : k => v if v.internal } : {}

  account_id     = var.account_id
  application_id = cloudflare_zero_trust_access_application.internal_services[each.key].id
  name           = "Allow Authentik users"
  precedence     = index(local.internal_keys, each.key) * 2
  decision       = "allow"

  include {
    everyone = true
  }
}

# Policy: allow specific emails (fallback when not using Authentik)
resource "cloudflare_zero_trust_access_policy" "internal_allow" {
  for_each = { for k, v in var.homelab_services : k => v if v.internal }

  account_id     = var.account_id
  application_id = cloudflare_zero_trust_access_application.internal_services[each.key].id
  name           = "Allow homelab admins"
  precedence     = 100 + index(local.internal_keys, each.key) * 2 + 1
  decision       = "allow"

  include {
    email = var.allowed_emails
  }
}
