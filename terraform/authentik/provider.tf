# Authentik Terraform configuration
# See: _bmad-output/implementation-artifacts/authentik-terraform-implementation.md
# Auth: set AUTHENTIK_URL and AUTHENTIK_TOKEN (e.g. via .env, not committed)

terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2025.12"
    }
  }
}

provider "authentik" {
  # URL and token from environment: AUTHENTIK_URL, AUTHENTIK_TOKEN
}
