# =============================================================================
# Auth0 Terraform configuration
# Secrets stored in Doppler for backup/recovery
# =============================================================================

terraform {
  required_version = ">= 1.12"

  required_providers {
    auth0 = {
      source  = "auth0/auth0"
      version = "~> 1.0"
    }
    doppler = {
      source  = "DopplerHQ/doppler"
      version = ">= 1.0"
    }
  }
}

# =============================================================================
# Variables & Doppler Secrets
# =============================================================================
variable "doppler_project" {
  description = "Doppler project name"
  type        = string
  default     = "infrastructure"
}

variable "doppler_environment" {
  description = "Doppler environment (config)"
  type        = string
  default     = "prd"
}

provider "doppler" {
  doppler_token = var.doppler_token
}

data "doppler_secrets" "this" {
  project = var.doppler_project
  config  = var.doppler_environment
}

locals {
  auth0_domain        = data.doppler_secrets.this.map.AUTH0_DOMAIN
  auth0_client_id     = data.doppler_secrets.this.map.AUTH0_CLIENT_ID
  auth0_client_secret = data.doppler_secrets.this.map.AUTH0_CLIENT_SECRET
}

# Use client credentials (M2M) instead of a static api_token.
# This auto-renews via OAuth2 and never expires.
provider "auth0" {
  domain        = local.auth0_domain
  client_id     = local.auth0_client_id
  client_secret = local.auth0_client_secret
}
