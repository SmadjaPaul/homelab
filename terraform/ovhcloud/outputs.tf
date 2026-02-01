# =============================================================================
# OVHcloud Object Storage Outputs
# =============================================================================

output "velero_bucket" {
  description = "Velero S3 bucket details (null until ovh_s3_access_key/secret_key are set and bucket is created)"
  value = local.ovh_s3_credentials_set && length(aws_s3_bucket.velero) > 0 ? {
    name        = aws_s3_bucket.velero[0].id
    region      = var.s3_region
    s3_endpoint = "https://s3.${var.s3_region}.io.cloud.ovh.net"
  } : null
  sensitive = true
}

output "velero_s3_credentials" {
  description = "S3 credentials for Velero (from OVH user). Use these in ovh_s3_access_key/ovh_s3_secret_key for second apply, then configure Velero."
  value = {
    access_key_id     = ovh_cloud_project_user_s3_credential.velero.access_key_id
    secret_access_key = ovh_cloud_project_user_s3_credential.velero.secret_access_key
  }
  sensitive = true
}

output "s3_endpoint" {
  description = "OVH S3-compatible endpoint URL"
  value       = "https://s3.${var.s3_region}.io.cloud.ovh.net"
}

output "object_storage_user_id" {
  description = "OVH Object Storage user ID (for Velero and long-term archive)"
  value       = ovh_cloud_project_user.velero.id
}

# Archive long terme (données utilisateur ZFS/Nextcloud)
output "long_term_bucket" {
  description = "Long-term user data archive bucket (ZFS, Nextcloud « do not lose »). Same credentials as velero_s3_credentials."
  value = local.ovh_s3_credentials_set && length(aws_s3_bucket.long_term_user_data) > 0 ? {
    name        = aws_s3_bucket.long_term_user_data[0].id
    region      = var.s3_region
    s3_endpoint = "https://s3.${var.s3_region}.io.cloud.ovh.net"
    prefixes    = "zfs/, nextcloud/ (recommended; config to finalize)"
  } : null
  sensitive = true
}
