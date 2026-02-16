# Object Storage Module

# Terraform State Bucket
resource "oci_objectstorage_bucket" "terraform_state" {
  compartment_id = var.compartment_id
  namespace      = var.namespace
  name           = var.bucket_name
  storage_tier   = "Standard"

  versioning            = "Enabled"
  encryption            = "OracleManaged"
  object_events_enabled = false

  freeform_tags = var.tags
}

# =============================================================================
# Outputs
# =============================================================================

output "bucket_name" {
  value = oci_objectstorage_bucket.terraform_state.name
}

output "bucket_id" {
  value = oci_objectstorage_bucket.terraform_state.id
}
