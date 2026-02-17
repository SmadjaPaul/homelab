# -----------------------------------------------------------------------------
# Remote State Management - OCI Object Storage
# -----------------------------------------------------------------------------
# - Remote backend: state dans OCI Object Storage (Always Free: 20 GB, 50k req/mois)
# - State locking: natif OCI
# - Versioning: bucket homelab-tfstate avec versioning = "Enabled"
# - Auth: même auth que le provider OCI (~/.oci/config ou env OCI_CLI_*)
# -----------------------------------------------------------------------------

terraform {
  backend "oci" {
    bucket    = "homelab-tfstate"
    namespace = "axnvxxurxefp"
    key       = "oracle-cloud/terraform.tfstate"
    region    = "eu-paris-1"
  }
}
