# Terraform Backend - OCI Object Storage
# Requires Terraform 1.11.0+ for native OCI backend support

terraform {
  backend "oci" {
    bucket    = "homelab-tfstate"
    namespace = "YOUR_TENANCY_NAMESPACE" # CI: injected by workflow; Local: replace manually
    key       = "proxmox/terraform.tfstate"
    region    = "eu-paris-1"
  }
}
