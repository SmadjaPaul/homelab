output "omni_application_uuid" {
  value = authentik_application.omni.uuid
}

output "litellm_application_uuid" {
  value = authentik_application.litellm.uuid
}

output "openclaw_application_uuid" {
  value = authentik_application.openclaw.uuid
}

output "openclaw_oidc_application_uuid" {
  value = authentik_application.openclaw_oidc.uuid
}

output "odoo_application_uuid" {
  value = authentik_application.odoo.uuid
}

output "omni_outpost_note" {
  description = "After apply: set AUTHENTIK_OUTPOST_TOKEN from Authentik UI"
  value       = "Outpost 'Homelab Forward Auth' created. Get its token in Authentik → Avant-postes → Homelab Forward Auth, then set AUTHENTIK_OUTPOST_TOKEN in docker/oci-mgmt/.env and restart authentik-outpost-proxy."
}

output "openclaw_oidc" {
  description = "OIDC settings for OpenClaw (AUTHENTICATION_METHOD=oidc)"
  value = {
    issuer                 = local.openclaw_oidc_issuer
    client_id              = authentik_provider_oauth2.openclaw_oidc.client_id
    client_secret          = authentik_provider_oauth2.openclaw_oidc.client_secret
    redirect_uri           = local.openclaw_oidc_redirect_production
    redirect_uri_localhost = local.openclaw_oidc_redirect_localhost
  }
  sensitive = true
}

output "cloudflare_access_oidc" {
  description = "OIDC credentials and URLs for Cloudflare Zero Trust IdP configuration"
  value = {
    client_id     = authentik_provider_oauth2.cloudflare_access.client_id
    client_secret = authentik_provider_oauth2.cloudflare_access.client_secret
    auth_url      = "${local.authentik_base_url}/application/o/authorize/"
    token_url     = "${local.authentik_base_url}/application/o/token/"
    certs_url     = "${local.authentik_base_url}/application/o/jwks/"
    issuer        = local.authentik_base_url
  }
  sensitive = true
}
