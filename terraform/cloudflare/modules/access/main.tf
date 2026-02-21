# =============================================================================
# Cloudflare Access — Auth0 IdP, applications, policies
# =============================================================================

locals {
  auth0_base    = "https://${var.auth0_domain}/"
  auth0_auth    = "${local.auth0_base}authorize"
  auth0_token   = "${local.auth0_base}oauth/token"
  auth0_certs   = "${local.auth0_base}.well-known/jwks.json"
  internal_keys = sort(keys({ for k, v in var.homelab_services : k => v if v.internal }))

  # Determine which IdP is enabled
  use_auth0   = var.auth0_oidc_enabled && length(var.auth0_oidc_client_id) > 0
  active_idps = local.use_auth0 ? [cloudflare_zero_trust_access_identity_provider.auth0[0].id] : []
}

# IdP: Auth0 (OIDC)
resource "cloudflare_zero_trust_access_identity_provider" "auth0" {
  count = var.auth0_oidc_enabled && length(var.auth0_oidc_client_id) > 0 ? 1 : 0

  account_id = var.account_id
  name       = "Auth0"
  type       = "saml"

  config = {
    sso_target_url = "${local.auth0_base}samlp/${var.auth0_oidc_client_id}"
    issuer_url     = "urn:${var.auth0_domain}"
    idp_public_certs = [
      <<-EOT
-----BEGIN CERTIFICATE-----
MIIDHTCCAgWgAwIBAgIJHbEYi6ELNXTCMA0GCSqGSIb3DQEBCwUAMCwxKjAoBgNV
BAMTIWRldi1yNXdpcGx4Z3Nia2lndmRrLmV1LmF1dGgwLmNvbTAeFw0yNjAyMjAw
ODU2NDhaFw0zOTEwMzAwODU2NDhaMCwxKjAoBgNVBAMTIWRldi1yNXdpcGx4Z3Ni
a2lndmRrLmV1LmF1dGgwLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
ggEBANjjcEkX1+9u/TY5Q8reomvMilgg8OOjzoOmDMwDGgAyRZ4I4ApQ9+TWyVst
/B+vcxw1E1sRFwREiJb9gFubz0rgvyzwSHrP9TD9cJKI/8eq4SXRnPYWzo28i6Eu
7aCpk/7xUx30yDyLSSuaD20/wP84YJp+ePXWjmUfWG0QLVLjnSROroX5diIFvHXZ
H6PiEFYpC1ymC8ufUJQ1I44g7swOaQRMznnNlGx07XDWTcLKW0uFHCamqEjX/Qwj
g3oxUGXOciztJE8c2J+iH+VIHmpuYpznf4ObftoncOkUX+KlCB91IKApFDY3pmhB
usz76lMT7IHpSeVvU8sGfT8A/hsCAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAd
BgNVHQ4EFgQUvy5TcSHZpUFIdJ6Rcq7YZWH0kmQwDgYDVR0PAQH/BAQDAgKEMA0G
CSqGSIb3DQEBCwUAA4IBAQBPAL7ikVceRmfPjuJz7QdeuiQwejXxGFOqIvF/Rf+d
Pob92xtAO7rsR97tIUyhLDHF5FuVwEBGtTqp/dzC3hSblpRrrX1bK02xiKlCfsvF
LfGdqkzdcdCUIF/8P6VOHoQv2AEJ5paBCQsNTNSTgWLaX2JQ5h1QYEk/mTyNL9nL
nsgvSVoCn1lRQyyVtjKPvF0rQ84S+B1FI7J/lGePZ0STGaSc1mDUekCrO2DKxZLe
D261lDrktz3ym3moOgv+llBIfgK4LC/q9IbeG9ubK26UbIZYhdlaf8hXYv0JZyxH
VpKAhnrHUohvaF7m80Zt/EVD3kbvNfZMehY3S41zky/G
-----END CERTIFICATE-----
EOT
    ]
    attributes           = ["email", "roles"]
    email_attribute_name = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
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
}

# Policy: allow everyone who authenticated via Auth0 (RBAC now enforced by Auth0 Action)
resource "cloudflare_zero_trust_access_policy" "idp_users" {
  count = var.auth0_oidc_enabled ? 1 : 0

  account_id = var.account_id
  name       = "Allow authenticated users"
  decision   = "allow"

  # Cloudflare free tier OIDC claim parsing workaround: allow everyone here,
  # but Auth0 Actions will block users without proper roles inside Auth0.
  include = [{
    everyone = {}
  }]
}

# Policy: allow specific emails (fallback)
resource "cloudflare_zero_trust_access_policy" "email_fallback" {
  count = length(var.allowed_emails) > 0 ? 1 : 0

  account_id = var.account_id
  name       = "Allow by email"
  decision   = "allow"

  include = [
    for e in var.allowed_emails : {
      email = { email = e }
    }
  ]
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

  # Attach policies in ascending order of precedence
  policies = concat(
    length(var.bypass_ips) > 0 ? [{ id = cloudflare_zero_trust_access_policy.ip_bypass[0].id }] : [],
    var.auth0_oidc_enabled ? [{ id = cloudflare_zero_trust_access_policy.idp_users[0].id }] : [],
    length(var.allowed_emails) > 0 ? [{ id = cloudflare_zero_trust_access_policy.email_fallback[0].id }] : []
  )
}

# =============================================================================
# App Launcher Note
# =============================================================================
# The App Launcher needs to be configured manually in Cloudflare Dashboard:
# 1. Go to Access controls > Access settings
# 2. Find "Manage your App Launcher" and click Manage
# 3. Add a policy allowing everyone: Include > Everyone
# 4. On Authentication tab, select Auth0 as the IdP
# =============================================================================
