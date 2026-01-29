# =============================================================================
# Cloudflare Terraform Configuration
# Domain: smadja.dev
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  # TFstate.dev for remote state (same as OCI)
  # Uses GITHUB_TOKEN for authentication - no additional secrets needed
  backend "http" {
    address        = "https://api.tfstate.dev/github/v1"
    lock_address   = "https://api.tfstate.dev/github/v1/lock"
    lock_method    = "PUT"
    unlock_address = "https://api.tfstate.dev/github/v1/lock"
    unlock_method  = "DELETE"
    username       = "SmadjaPaul/homelab"
    # TF_HTTP_PASSWORD is set to GITHUB_TOKEN in CI/CD
  }
}

# Configure the Cloudflare Provider
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Data source for the zone
data "cloudflare_zone" "main" {
  zone_id = var.zone_id
}
