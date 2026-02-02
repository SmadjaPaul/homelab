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

  # OCI Object Storage backend (same as oracle-cloud module)
  # No additional secrets needed - uses OCI session token from GitHub Secrets
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
