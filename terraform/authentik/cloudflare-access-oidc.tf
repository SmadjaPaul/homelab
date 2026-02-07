# =============================================================================
# Authentik as OIDC Identity Provider for Cloudflare Access
# =============================================================================
# Creates an OAuth2/OIDC provider so Cloudflare Zero Trust can use Authentik
# for login. Users who exist in Authentik can then access apps protected by
# Cloudflare Access without maintaining a separate email list.
#
# Docs: https://docs.goauthentik.io/integrations/services/cloudflare-access/
#       https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/generic-oidc/
# =============================================================================

variable "cloudflare_access_team" {
  description = "Cloudflare Access team subdomain (e.g. smadja for smadja.cloudflareaccess.com)"
  type        = string
  default     = "smadja"
}

locals {
  authentik_base_url = coalesce(
    var.authentik_url,
    "https://auth.${var.domain}"
  )
  cloudflare_callback_url = "https://${var.cloudflare_access_team}.cloudflareaccess.com/cdn-cgi/access/callback"
}

# OAuth2/OIDC provider for Cloudflare Access
resource "authentik_provider_oauth2" "cloudflare_access" {
  name               = "Cloudflare Access"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id
  client_id          = "cloudflare-access-${var.cloudflare_access_team}"
  client_type        = "confidential"
  allowed_redirect_uris = [
    { url = local.cloudflare_callback_url, matching_mode = "strict" }
  ]
  signing_key            = data.authentik_certificate_key_pair.default.id
  access_token_validity  = "hours=1"
  refresh_token_validity = "days=30"
}

# Application so the provider is usable (required by Authentik)
resource "authentik_application" "cloudflare_access" {
  name               = "Cloudflare Access (IdP)"
  slug               = "cloudflare-access"
  protocol_provider  = authentik_provider_oauth2.cloudflare_access.id
  policy_engine_mode = "any"
}

# Outputs for use in Terraform Cloudflare module
output "cloudflare_access_oidc" {
  description = "OIDC credentials and URLs for Cloudflare Zero Trust IdP configuration"
  value = {
    client_id     = authentik_provider_oauth2.cloudflare_access.client_id
    client_secret = authentik_provider_oauth2.cloudflare_access.client_secret
    auth_url      = "${local.authentik_base_url}/application/o/authorize/"
    token_url     = "${local.authentik_base_url}/application/o/token/"
    # Cloudflare calls this "Certificate URL" (JWKS for token verification)
    certs_url = "${local.authentik_base_url}/application/o/jwks/"
    issuer    = local.authentik_base_url
  }
  sensitive = true
}
