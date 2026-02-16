# Remote state in OCI Object Storage (same bucket as cloudflare/authentik).
# Optional: comment out to use local state. CI: add inject step and job if needed.
terraform {
  backend "oci" {
    bucket    = "homelab-tfstate"
    namespace = "YOUR_TENANCY_NAMESPACE"
    key       = "litellm/terraform.tfstate"
    region    = "eu-paris-1"
  }
}
