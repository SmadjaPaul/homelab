# -----------------------------------------------------------------------------
# Remote State Management - OCI Object Storage
# -----------------------------------------------------------------------------

terraform {
  backend "oci" {
    bucket    = "homelab-tfstate"
    namespace = "axnvxxurxefp"
    key       = "auth0/terraform.tfstate"
    region    = "eu-paris-1"
  }
}
