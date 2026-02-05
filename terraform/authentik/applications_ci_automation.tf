# OAuth2 Provider générique pour CI/CD (GitHub Actions)
# Utilisé par : Omni GitOps, Terraform Authentik, ArgoCD, et autres services CI/CD
# Flow: GitHub Actions (OIDC) → Authentik (OAuth2 client_credentials) → Services (Omni, Authentik API, ArgoCD, etc.)
# Ref: https://docs.goauthentik.io/add-secure-apps/providers/oauth2/#machine-to-machine-authentication
#
# Note: data.authentik_flow.default_authorization_flow est défini dans data.tf

# OAuth2 Provider pour CI/CD (machine-to-machine, client_credentials)
# Utilisé par Omni GitOps et autres workflows ; Terraform Authentik utilise un token statique (AUTHENTIK_TOKEN).
resource "authentik_provider_oauth2" "ci_automation" {
  name                       = "ci-automation"
  client_type                = "confidential"
  client_id                  = "ci-automation"
  authorization_flow         = data.authentik_flow.default_authorization_flow.id
  invalidation_flow          = data.authentik_flow.default_invalidation.id
  sub_mode                   = "user_username"
  include_claims_in_id_token = true
  # Grant type Client credentials activé via null_resource (provider_ci_automation_config.tf)
}

# Application pour CI/CD Automation (utilise le provider OAuth2)
resource "authentik_application" "ci_automation" {
  name               = "CI/CD Automation (GitHub Actions)"
  slug               = "ci-automation"
  protocol_provider  = authentik_provider_oauth2.ci_automation.id
  policy_engine_mode = "any"
}

# Outputs pour récupérer client_id et client_secret (à mettre dans GitHub Secrets)
output "ci_automation_oauth2_client_id" {
  description = "OAuth2 client_id for CI/CD automation (Omni, Terraform Authentik, ArgoCD, etc.). Add to GitHub Secrets: CI_AUTOMATION_AUTHENTIK_CLIENT_ID"
  value       = authentik_provider_oauth2.ci_automation.client_id
  sensitive   = false
}

output "ci_automation_oauth2_client_secret" {
  description = "OAuth2 client_secret for CI/CD automation. Add to GitHub Secrets: CI_AUTOMATION_AUTHENTIK_CLIENT_SECRET"
  value       = authentik_provider_oauth2.ci_automation.client_secret
  sensitive   = true
}

output "ci_automation_oauth2_issuer_url" {
  description = "Authentik OAuth2 issuer URL (for token endpoint)"
  value       = "https://auth.smadja.dev/application/o/${authentik_application.ci_automation.slug}/"
}

output "ci_automation_oauth2_provider_uuid" {
  description = "UUID of the OAuth2 provider (for API updates)"
  value       = authentik_provider_oauth2.ci_automation.id
  sensitive   = false
}
