# Terraform Backend - TFstate.dev (aligné avec OCI/OVH/Cloudflare)
# https://tfstate.dev/

terraform {
  backend "http" {
    address        = "https://api.tfstate.dev/github/v1"
    lock_address   = "https://api.tfstate.dev/github/v1/lock"
    unlock_address = "https://api.tfstate.dev/github/v1/lock"
    lock_method    = "PUT"
    unlock_method  = "DELETE"
    username       = "SmadjaPaul/homelab"
  }
}
