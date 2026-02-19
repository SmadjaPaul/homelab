# Authentik Terraform configuration
# Auth: secrets fetched directly from Doppler
# SMTP secrets: managed in Doppler (project: authentik)

terraform {
  required_version = ">= 1.12"

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
      version = ">= 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Doppler provider - uses DOPPLER_TOKEN env var
provider "doppler" {}

# Fetch secrets from Doppler
data "doppler_secrets" "this" {
  project = "infrastructure"
  config  = "prd"
}

# Variable pour l'URL Authentik (permet d'utiliser Tailscale)
variable "authentik_url" {
  type        = string
  default     = ""
  description = "URL Authentik (utilise Tailscale IP si vide, sinon URL depuis Doppler)"
}

# Locals pour déterminer l'URL à utiliser
locals {
  authentik_url = var.authentik_url != "" ? var.authentik_url : lookup(
    data.doppler_secrets.this.map,
    "AUTHENTIK_URL",
    "https://auth.smadja.dev"
  )
}

provider "authentik" {
  url   = local.authentik_url
  token = lookup(data.doppler_secrets.this.map, "AUTHENTIK_TOKEN", "")
}

variable "doppler_token" {
  type        = string
  default     = ""
  description = "Doppler token for secrets (defaults to DOPPLER_TOKEN env)"
}

# Variable pour forcer la rotation des mots de passe
variable "force_password_rotation" {
  type        = bool
  default     = false
  description = "Force la rotation de tous les mots de passe utilisateurs"
}

# Variable pour générer un nouveau trigger de rotation
variable "password_rotation_trigger" {
  type        = string
  default     = "initial"
  description = "Changez cette valeur pour déclencher une rotation de mots de passe (ex: 'v1', 'v2', etc.)"
}
