# =============================================================================
# Backend Configuration
# =============================================================================

terraform {
  backend "oci" {
    bucket    = "homelab-tfstate"
    namespace = "axnvxxurxefp"
    key       = "netbird/terraform.tfstate"
    region    = "eu-paris-1"
  }
}
