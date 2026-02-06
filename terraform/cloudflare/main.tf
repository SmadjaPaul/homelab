# =============================================================================
# Cloudflare Terraform Configuration
# Domain: smadja.dev
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.16"
    }
  }

  # OCI Object Storage backend (same as oracle-cloud module)
  # Requires Terraform 1.11.0+ for native OCI backend support
  backend "oci" {
    bucket    = "homelab-tfstate"
    namespace = "YOUR_TENANCY_NAMESPACE" # CI: injected by workflow; Local: replace manually
    key       = "cloudflare/terraform.tfstate"
    region    = "eu-paris-1"
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
