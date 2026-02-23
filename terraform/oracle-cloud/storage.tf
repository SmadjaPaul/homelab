# =============================================================================
# Object Storage for Velero Backups
# =============================================================================

# Get object storage namespace
data "oci_objectstorage_namespace" "user_namespace" {
  compartment_id = var.compartment_id
}

# Create Object Storage Bucket for Velero
resource "oci_objectstorage_bucket" "velero_backups" {
  compartment_id = var.compartment_id
  namespace      = data.oci_objectstorage_namespace.user_namespace.namespace
  name           = "velero-backups"
  access_type    = "NoPublicAccess"

  # Optional: Auto tiering or lifecycle policies can be added here
}

# =============================================================================
# S3 Credentials for Velero
# =============================================================================

# Generate Customer Secret Key for S3 compatibility
resource "oci_identity_customer_secret_key" "velero_s3_key" {
  display_name = "velero-s3-credentials"
  user_id      = local.oci_user_ocid
}

# =============================================================================
# Outputs for Velero S3 credentials
# =============================================================================

output "velero_s3_access_key" {
  description = "Access key for Velero S3 configuration"
  value       = oci_identity_customer_secret_key.velero_s3_key.id
  sensitive   = true
}

output "velero_s3_secret_key" {
  description = "Secret key for Velero S3 configuration"
  value       = oci_identity_customer_secret_key.velero_s3_key.key
  sensitive   = true
}

output "velero_bucket_name" {
  description = "Name of the Velero backups bucket"
  value       = oci_objectstorage_bucket.velero_backups.name
}

output "velero_s3_url" {
  description = "S3 URL for the OCI Object Storage region"
  value       = "https://${data.oci_objectstorage_namespace.user_namespace.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"
}
