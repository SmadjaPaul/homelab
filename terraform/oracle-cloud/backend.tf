# =============================================================================
# Backend Configuration - OCI Object Storage (S3-compatible)
# Works both locally (with OCI CLI) and in CI (with secrets)
# =============================================================================

terraform {
  # Local backend by default - use: terraform init -backend-config=backend.hcl
  # to use remote backend with OCI Object Storage
}
