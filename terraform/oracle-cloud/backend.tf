# Terraform Backend Configuration
# Using TFstate.dev - Free Terraform State hosting with GitHub Auth
# https://tfstate.dev/
#
# Features:
# - Uses GitHub Token for authentication
# - Encrypted state in AWS S3 with KMS
# - State locking included
# - No additional setup required

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

# To initialize with GitHub token:
# export TF_HTTP_PASSWORD="ghp_your_github_token"
# terraform init
#
# In GitHub Actions, the token is automatically available via secrets.GITHUB_TOKEN
