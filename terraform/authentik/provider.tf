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
  }
}

provider "doppler" {
  doppler_token = var.doppler_token
}

data "doppler_secrets" "this" {
  project = "infrastructure"
  config  = "prd"
}

provider "authentik" {
  url   = var.authentik_url
  token = var.authentik_token
}
