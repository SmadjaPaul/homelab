terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2024.12.0"
    }
    doppler = {
      source  = "dopplerhq/doppler"
      version = "1.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.0"
    }
  }
}

provider "doppler" {
  doppler_token = var.doppler_token
}

# Create/update the OAuth2 client secret in Doppler
resource "doppler_secret" "audiobookshelf_oidc_client_secret" {
  project = "infrastructure"
  config  = "prd"
  name    = "AUDIOBOOKSHELF_OIDC_CLIENT_SECRET"
  value   = random_password.audiobookshelf_client_secret.result
}

# Generate a random client secret if not exists
resource "random_password" "audiobookshelf_client_secret" {
  length  = 32
  special = false
}

data "doppler_secrets" "this" {
  project = "infrastructure"
  config  = "prd"
}

provider "authentik" {
  url   = var.authentik_url
  token = var.authentik_token
}
