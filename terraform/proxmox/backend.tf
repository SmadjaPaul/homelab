# Terraform Backend - OCI Object Storage (unified with other modules)
# Uses OCI session token for authentication

terraform {
  backend "oci" {
    bucket    = "homelab-tfstate"
    namespace = "YOUR_TENANCY_NAMESPACE" # CI: injected by workflow; Local: replace manually
    key       = "proxmox/terraform.tfstate"
    region    = "eu-paris-1"
  }
}
