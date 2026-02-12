# Remote state in OCI Object Storage (same bucket as cloudflare / oracle-cloud).
# Requires Terraform 1.11+ and OCI auth (env OCI_CLI_* or ~/.oci/config).
# CI: namespace injected by workflow (sed). Local: replace YOUR_TENANCY_NAMESPACE then init -reconfigure.
terraform {
  backend "oci" {
    bucket    = "homelab-tfstate"
    namespace = "YOUR_TENANCY_NAMESPACE"
    key       = "authentik/terraform.tfstate"
    region    = "eu-paris-1"
  }
}
