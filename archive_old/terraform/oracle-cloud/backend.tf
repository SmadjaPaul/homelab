# -----------------------------------------------------------------------------
# Remote State Management (bonnes pratiques)
# -----------------------------------------------------------------------------
# - Remote backend: state dans OCI Object Storage (Always Free: 20 GB, 50k req/mois)
# - State locking: natif OCI (If-None-Match) — évite modifications concurrentes
# - Versioning: bucket homelab-tfstate avec versioning = "Enabled" (backups / rollback)
# - State isolation: workspaces (terraform workspace new/select) ou key par env
#   Ex. key prod: -backend-config="key=oracle-cloud/prod/terraform.tfstate"
# - Auth: même auth que le provider OCI (~/.oci/config ou env OCI_CLI_*)
# - Namespace: défini ci-dessous (obligatoire). Le backend "oci" n'accepte pas
#   namespace via -backend-config ; en CI il est injecté depuis le secret.
#   Local : remplacer axnvxxurxefp par ton namespace (terraform output tfstate_bucket) ; CI : injecté.
# https://developer.hashicorp.com/terraform/language/backend/oci
# -----------------------------------------------------------------------------

terraform {
  backend "oci" {
    bucket    = "homelab-tfstate"
    namespace = "axnvxxurxefp" # Remplacer par ton namespace tenancy (voir README) ; CI : injecté par le workflow
    key       = "oracle-cloud/terraform.tfstate"
    region    = "eu-paris-1"
  }
}
