# Authentik Terraform configuration
# Auth: set AUTHENTIK_URL and AUTHENTIK_TOKEN (e.g. via .env, not committed)
# SMTP secrets: managed in Doppler (project: authentik)

terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2024.12"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    doppler = {
      source  = "DopplerHQ/doppler"
      version = "1.13.0"
    }
  }
}

provider "authentik" {
  url   = var.authentik_url
  token = var.authentik_token
}

# Doppler provider - uses DOPPLER_TOKEN env var
provider "doppler" {
  doppler_token = var.doppler_token
}

variable "doppler_token" {
  type        = string
  default     = ""
  description = "Doppler token for secrets (defaults to DOPPLER_TOKEN env)"
}
