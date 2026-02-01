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

# To initialize with GitHub token (CI backend):
#   export TF_HTTP_PASSWORD="ghp_your_github_token"   # or TFSTATE_DEV_TOKEN
#   terraform init -reconfigure
#
# To force-unlock the CI state when a run left a stale lock (use same backend as CI):
#   1. Rename backend override so Terraform uses HTTP:  mv backend_override.tf backend_override.tf.bak
#   2. terraform init -reconfigure
#   3. terraform force-unlock <LOCK_ID>
#   4. Restore override:  mv backend_override.tf.bak backend_override.tf
#
# In GitHub Actions, the token is automatically available via secrets.GITHUB_TOKEN
