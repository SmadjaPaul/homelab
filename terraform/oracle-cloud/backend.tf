# =============================================================================
# Backend Configuration - OCI Object Storage (S3-compatible)
# =============================================================================

terraform {
  backend "s3" {
    bucket                      = "terraform-states"
    key                         = "oracle-cloud/terraform.tfstate"
    region                      = "eu-paris-1"
    endpoint                    = "https://YOUR_NAMESPACE.compat.objectstorage.eu-paris-1.oraclecloud.com"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    force_path_style            = true
  }
}
