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

  # Local backend for now - can switch to TFstate.dev later
  backend "local" {
    path = "terraform.tfstate"
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
