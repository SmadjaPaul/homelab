# -----------------------------------------------------------------------------
# Remote State Management - OCI Object Storage
# -----------------------------------------------------------------------------
# Backend natif OCI disponible depuis Terraform 1.12
# Nécessite Terraform >= 1.12.0
# -----------------------------------------------------------------------------

terraform {
  backend "oci" {
    bucket    = "homelab-tfstate"
    namespace = "axnvxxurxefp"
    key       = "cloudflare/terraform.tfstate"
    region    = "eu-paris-1"
  }
}
