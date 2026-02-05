# OAuth Source for CI/CD Automation (private_key_jwt)
# This source stores the public key (JWKS) used to verify JWT assertions from GitHub Actions
# Ref: https://docs.goauthentik.io/docs/add-secure-apps/providers/oauth2/client_credentials

# OAuth Source for CI/CD Automation
# This source stores the public key (JWKS) used to verify JWT assertions from GitHub Actions
# For OpenID Connect sources, authorization_url/access_token_url/profile_url are required
# We use Authentik's own well-known endpoint for discovery (not used for JWKS-only, but required)
# The JWKS data itself is managed via API (updated by GitHub Actions workflows)
resource "authentik_source_oauth" "ci_automation_jwks" {
  name                = "ci-automation-jwks"
  slug                = "ci-automation-jwks"
  authentication_flow = data.authentik_flow.default_authorization_flow.id
  enrollment_flow     = data.authentik_flow.default_authorization_flow.id
  provider_type       = "openidconnect"

  # Required fields for OAuth Source OpenID Connect (not used for JWKS-only, but required by Terraform)
  # Using Authentik's own well-known endpoint for discovery
  authorization_url = "https://auth.smadja.dev/.well-known/openid-configuration"
  access_token_url  = "https://auth.smadja.dev/application/o/ci-automation/token/"
  profile_url       = "https://auth.smadja.dev/api/v3/core/users/me/"
  consumer_key      = "jwks-only-not-used"
  consumer_secret   = "jwks-only-not-used"

  # JWKS configuration
  # Note: JWKS data is managed via API/UI or updated via workflow
  # The actual JWKS content will be set via Authentik API by GitHub Actions workflows
  # (see .github/workflows/authentik-deploy-jwks.yml and authentik-rotate-keys.yml)
}

# Output the source UUID for API updates
output "ci_automation_oauth_source_uuid" {
  description = "UUID of the OAuth Source for CI/CD automation (for JWKS updates via API)"
  value       = authentik_source_oauth.ci_automation_jwks.id
  sensitive   = false
}
