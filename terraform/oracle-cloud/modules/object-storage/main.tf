# Object Storage Module

# Terraform State Bucket
resource "oci_objectstorage_bucket" "terraform_state" {
  compartment_id        = var.compartment_id
  namespace             = var.namespace
  name                  = var.bucket_name
  storage_tier          = "Standard"
  versioning            = "Enabled"
  object_events_enabled = false

  metadata = {
    "project" = "homelab"
    "purpose" = "terraform-state"
  }

  freeform_tags = var.tags
}

# Limiter les anciennes versions : suppression après N jours (OCI ne permet pas "garder 20 versions" en nombre)
# Avec 20 jours, tu conserves environ 20 versions si tu appliques ~1×/jour
resource "oci_objectstorage_object_lifecycle_policy" "state_version_retention" {
  namespace = var.namespace
  bucket    = oci_objectstorage_bucket.terraform_state.name

  rules {
    name        = "delete-old-state-versions"
    action      = "DELETE"
    target      = "previousVersions"
    time_amount = var.version_retention_days
    time_unit   = "DAYS"
    is_enabled  = true
  }
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
