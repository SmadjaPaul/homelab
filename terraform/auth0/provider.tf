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
variable "doppler_token" {
  description = "Doppler API token for storing secrets"
  type        = string
  sensitive   = true
}

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
  auth0_domain    = data.doppler_secrets.this.map.AUTH0_DOMAIN
  auth0_api_token = data.doppler_secrets.this.map.AUTH0_API_TOKEN
}

provider "auth0" {
  domain    = local.auth0_domain
  api_token = local.auth0_api_token
}
