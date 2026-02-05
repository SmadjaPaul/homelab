# OCI Object Storage backend (same as oracle-cloud and cloudflare modules)
# Requires Terraform 1.11.0+ for native OCI backend support
terraform {
  backend "oci" {
    bucket    = "homelab-tfstate"
    namespace = "axnvxxurxefp" # Remplacer par ton namespace tenancy (voir README) ; CI : injecté par le workflow
    key       = "authentik/terraform.tfstate"
    region    = "eu-paris-1"
  }
}
