# =============================================================================
# Cloudflare Access — Auth0 IdP, applications, policies
# =============================================================================

locals {
  auth0_base    = "https://${var.auth0_domain}"
  auth0_issuer  = "https://${var.auth0_domain}/"
  auth_url      = "${local.auth0_base}/authorize"
  token_url     = "${local.auth0_base}/oauth/token"
  certs_url     = "${local.auth0_base}/.well-known/jwks.json"
  internal_keys = sort(keys({ for k, v in var.homelab_services : k => v if v.internal }))

  # Determine which IdP is enabled
  use_auth0   = var.auth0_oidc_enabled && length(var.auth0_oidc_client_id) > 0
  active_idps = local.use_auth0 ? [cloudflare_zero_trust_access_identity_provider.auth0[0].id] : []
}
resource "cloudflare_zero_trust_access_identity_provider" "auth0" {
  count = var.auth0_oidc_enabled && length(var.auth0_oidc_client_id) > 0 ? 1 : 0

  account_id = var.account_id
  name       = "Auth0"
  type       = "oidc"

  config = {
    client_id        = var.auth0_oidc_client_id
    client_secret    = var.auth0_oidc_client_secret
    auth_url         = local.auth_url
    token_url        = local.token_url
    certs_url        = local.certs_url
    scopes           = ["openid", "profile", "email"]
    pkce_enabled     = true
    email_claim_name = "email"
  }
}

# =============================================================================
# Reusable Access Policies
# =============================================================================

# Policy: bypass Access for specific IPs (Terraform, API access) - highest priority
resource "cloudflare_zero_trust_access_policy" "ip_bypass" {
  count = length(var.bypass_ips) > 0 ? 1 : 0

  account_id = var.account_id
  name       = "Allow from bypass IPs"
  decision   = "allow"

  include = [
    for ip in var.bypass_ips : {
      ip = { ip = ip }
    }
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Policy: allow all authenticated Auth0 users (SIMPLE - no RBAC)
resource "cloudflare_zero_trust_access_policy" "auth0_users" {
  count = var.auth0_oidc_enabled ? 1 : 0

  account_id = var.account_id
  name       = "Allow Auth0 users"
  decision   = "allow"

  include = [{
    everyone = {}
  }]

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Access applications (internal services only)
# =============================================================================

resource "cloudflare_zero_trust_access_application" "internal_services" {
  for_each = { for k, v in var.homelab_services : k => v if v.internal }

  account_id       = var.account_id
  name             = "Homelab - ${each.value.description}"
  domain           = "${each.value.subdomain}.${var.domain}"
  type             = "self_hosted"
  session_duration = "24h"

  auto_redirect_to_identity = true
  allowed_idps              = local.active_idps
  skip_interstitial         = var.skip_interstitial
  options_preflight_bypass  = true

  # Simple policy: allow Auth0 users, or bypass IPs
  policies = concat(
    length(var.bypass_ips) > 0 ? [{ id = cloudflare_zero_trust_access_policy.ip_bypass[0].id }] : [],
    var.auth0_oidc_enabled ? [{ id = cloudflare_zero_trust_access_policy.auth0_users[0].id }] : []
  )
}
