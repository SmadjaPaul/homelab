# Terraform Backend Configuration
# 
# Option 1: Local state (current - simple for single user)
# Option 2: OCI Object Storage (recommended for CI/CD)
#
# To switch to remote state, uncomment the backend block below
# and run: terraform init -migrate-state

# terraform {
#   backend "s3" {
#     bucket                      = "homelab-terraform-state"
#     key                         = "oracle-cloud/terraform.tfstate"
#     region                      = "eu-paris-1"
#     endpoint                    = "https://<namespace>.compat.objectstorage.eu-paris-1.oraclecloud.com"
#     skip_region_validation      = true
#     skip_credentials_validation = true
#     skip_metadata_api_check     = true
#     force_path_style            = true
#   }
# }

# For now, state is stored locally
# In CI/CD, we'll use GitHub Actions artifacts to persist state
# or migrate to OCI Object Storage backend
