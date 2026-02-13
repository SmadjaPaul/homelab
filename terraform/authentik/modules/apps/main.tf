# =============================================================================
# Apps — Proxy providers (Omni, LiteLLM, OpenClaw), OIDC (OpenClaw, Cloudflare Access), Outpost
# =============================================================================

# ----- Proxy providers -----
resource "authentik_provider_proxy" "omni" {
  name               = "omni-proxy"
  mode               = "forward_single"
  authorization_flow = var.default_authorization_flow_id
  invalidation_flow  = var.default_invalidation_flow_id
  external_host      = "https://omni.${var.domain}"
}

resource "authentik_provider_proxy" "litellm" {
  name               = "litellm-proxy"
  mode               = "forward_single"
  authorization_flow = var.default_authorization_flow_id
  invalidation_flow  = var.default_invalidation_flow_id
  external_host      = "https://llm.${var.domain}"
}

resource "authentik_provider_proxy" "openclaw" {
  name               = "openclaw-proxy"
  mode               = "forward_single"
  authorization_flow = var.default_authorization_flow_id
  invalidation_flow  = var.default_invalidation_flow_id
  external_host      = "https://openclaw.${var.domain}"
}

# Odoo — accès réservé au groupe professionnelle (voir docs/authentik-rbac-spec.md)
resource "authentik_provider_proxy" "odoo" {
  name               = "odoo-proxy"
  mode               = "forward_single"
  authorization_flow = var.default_authorization_flow_id
  invalidation_flow  = var.default_invalidation_flow_id
  external_host      = "https://odoo.${var.domain}"
}

# ----- Proxy applications -----
resource "authentik_application" "omni" {
  name               = "Omni"
  slug               = "omni"
  protocol_provider  = authentik_provider_proxy.omni.id
  policy_engine_mode = "any"
}

resource "authentik_application" "litellm" {
  name               = "LiteLLM"
  slug               = "litellm"
  protocol_provider  = authentik_provider_proxy.litellm.id
  policy_engine_mode = "any"
}

resource "authentik_application" "openclaw" {
  name               = "OpenClaw"
  slug               = "openclaw"
  protocol_provider  = authentik_provider_proxy.openclaw.id
  policy_engine_mode = "any"
}

resource "authentik_application" "odoo" {
  name               = "Odoo"
  slug               = "odoo"
  protocol_provider  = authentik_provider_proxy.odoo.id
  policy_engine_mode = "any"
}

# ----- Outpost Forward Auth -----
resource "authentik_outpost" "proxy_forward_auth" {
  name               = "Homelab Forward Auth"
  type               = "proxy"
  protocol_providers = [authentik_provider_proxy.omni.id, authentik_provider_proxy.litellm.id, authentik_provider_proxy.openclaw.id, authentik_provider_proxy.odoo.id]
}

# ----- OpenClaw OIDC -----
locals {
  openclaw_oidc_redirect_production = "https://openclaw.${var.domain}/auth/callback"
  openclaw_oidc_redirect_localhost  = "http://localhost:3000/auth/callback"
  openclaw_oidc_issuer              = "${var.authentik_url}/application/o/openclaw-oidc/"
}

resource "authentik_provider_oauth2" "openclaw_oidc" {
  name                   = "OpenClaw (OIDC)"
  client_id              = "openclaw-oidc"
  client_type            = "confidential"
  authorization_flow     = var.default_authorization_flow_id
  invalidation_flow      = var.default_invalidation_flow_id
  signing_key            = var.default_certificate_key_pair_id
  access_token_validity  = "hours=1"
  refresh_token_validity = "days=30"
  sub_mode               = "user_username"

  allowed_redirect_uris = [
    { url = local.openclaw_oidc_redirect_production, matching_mode = "strict" },
    { url = local.openclaw_oidc_redirect_localhost, matching_mode = "strict" }
  ]
}

resource "authentik_application" "openclaw_oidc" {
  name               = "OpenClaw (OIDC Login)"
  slug               = "openclaw-oidc"
  protocol_provider  = authentik_provider_oauth2.openclaw_oidc.id
  policy_engine_mode = "any"
}

# ----- Cloudflare Access OIDC -----
locals {
  authentik_base_url      = var.authentik_url
  cloudflare_callback_url = "https://${var.cloudflare_access_team}.cloudflareaccess.com/cdn-cgi/access/callback"
}

resource "authentik_provider_oauth2" "cloudflare_access" {
  name               = "Cloudflare Access"
  authorization_flow = var.default_authorization_flow_id
  invalidation_flow  = var.default_invalidation_flow_id
  client_id          = "cloudflare-access-${var.cloudflare_access_team}"
  client_type        = "confidential"
  allowed_redirect_uris = [
    { url = local.cloudflare_callback_url, matching_mode = "strict" }
  ]
  signing_key            = var.default_certificate_key_pair_id
  access_token_validity  = "hours=1"
  refresh_token_validity = "days=30"
  # Scope mappings so Cloudflare Access gets user/group from UserInfo (fixes "Failed to fetch user/group information")
  property_mappings = var.default_oidc_scope_mapping_ids
}

resource "authentik_application" "cloudflare_access" {
  name               = "Cloudflare Access (IdP)"
  slug               = "cloudflare-access"
  protocol_provider  = authentik_provider_oauth2.cloudflare_access.id
  policy_engine_mode = "any"
}
