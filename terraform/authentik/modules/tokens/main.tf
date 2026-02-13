# =============================================================================
# Tokens — Create API tokens for Terraform/CI/CD
# =============================================================================
# Creates tokens with optional superuser permissions for full API access.
# Reference: https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/token
# =============================================================================

resource "authentik_user" "terraform_service" {
  count = var.create_service_account ? 1 : 0

  username  = "terraform-service"
  name      = "Terraform Service Account"
  path      = "service-accounts"
  type      = "service_account"
  is_active = true
}

resource "authentik_token" "terraform_token" {
  count = var.create_service_account ? 1 : 0

  identifier   = var.token_identifier
  user         = var.superuser ? authentik_user.terraform_service[0].id : var.user_id
  description  = "Terraform ${var.superuser ? "superuser" : ""} token for CI/CD"
  expires      = var.expires
  intent       = "api"
  retrieve_key = true

  lifecycle {
    create_before_destroy = true
  }
}

output "token_key" {
  description = "The token key (only available on create)"
  value       = var.create_service_account ? authentik_token.terraform_token[0].key : ""
  sensitive   = true
}

output "token_id" {
  description = "The token ID"
  value       = var.create_service_account ? authentik_token.terraform_token[0].id : ""
}
