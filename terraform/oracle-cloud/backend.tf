# -----------------------------------------------------------------------------
# Remote State Management (bonnes pratiques)
# -----------------------------------------------------------------------------
# - Remote backend: state dans OCI Object Storage (Always Free: 20 GB, 50k req/mois)
# - State locking: natif OCI (If-None-Match) — évite modifications concurrentes
# - Versioning: bucket homelab-tfstate avec versioning = "Enabled" (backups / rollback)
# - State isolation: workspaces (terraform workspace new/select) ou key par env
#   Ex. key prod: -backend-config="key=oracle-cloud/prod/terraform.tfstate"
# - Auth: même auth que le provider OCI (~/.oci/config ou env OCI_CLI_*)
# - Namespace tenancy: -backend-config="namespace=<tenancy_namespace>"
# https://developer.hashicorp.com/terraform/language/backend/oci
# -----------------------------------------------------------------------------

terraform {
  backend "oci" {
    bucket = "homelab-tfstate"
    key    = "oracle-cloud/terraform.tfstate"
    region = "eu-paris-1"
    # namespace requis : -backend-config="namespace=<tenancy_namespace>"
    # Après 1er apply : terraform output -json | jq -r '.tfstate_bucket.value.namespace'
  }
}
