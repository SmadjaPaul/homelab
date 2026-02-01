# Oracle Cloud Object Storage for Velero Backups
# Free tier: 20 GB total (Standard + Infrequent + Archive)

# -----------------------------------------------------------------------------
# IAM: autoriser le service Object Storage à gérer le lifecycle (archive/delete)
# Sans cette politique, PutObjectLifecyclePolicy renvoie InsufficientServicePermissions
# https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/usinglifecyclepolicies.htm
# -----------------------------------------------------------------------------
resource "oci_identity_policy" "object_storage_lifecycle" {
  compartment_id = var.compartment_id
  name           = "homelab-object-storage-lifecycle-service"
  description    = "Allow Object Storage service to manage lifecycle (archive/delete) on buckets"
  statements = [
    "Allow service objectstorage-${replace(var.region, ".", "-")} to manage object-family in tenancy"
  ]
}

# Get Object Storage namespace (required for bucket operations)
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_id
}

# Create bucket for Velero backups
resource "oci_objectstorage_bucket" "velero_backups" {
  compartment_id = var.compartment_id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "homelab-velero-backups"
  access_type    = "NoPublicAccess"

  # Use Standard tier for quick restores
  storage_tier = "Standard"

  # Enable versioning for safety
  versioning = "Enabled"

  # Metadata
  metadata = {
    project = "homelab"
    purpose = "velero-backups"
  }

  freeform_tags = {
    Project     = "homelab"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Lifecycle policy to auto-delete old backups (nécessite la policy IAM ci-dessus)
resource "oci_objectstorage_object_lifecycle_policy" "velero_lifecycle" {
  namespace  = data.oci_objectstorage_namespace.ns.namespace
  bucket     = oci_objectstorage_bucket.velero_backups.name
  depends_on = [oci_identity_policy.object_storage_lifecycle]

  rules {
    name        = "delete-old-backups"
    action      = "DELETE"
    time_amount = 14
    time_unit   = "DAYS"
    is_enabled  = true

    target = "objects"

    # Delete all objects older than 14 days
    object_name_filter {
      inclusion_prefixes = ["backups/", "restic/"]
    }
  }

  rules {
    name        = "archive-after-7-days"
    action      = "ARCHIVE"
    time_amount = 7
    time_unit   = "DAYS"
    is_enabled  = true

    target = "objects"

    object_name_filter {
      inclusion_prefixes = ["backups/"]
    }
  }
}

# Create a customer secret key for S3 compatibility
resource "oci_identity_customer_secret_key" "velero_s3_key" {
  display_name = "velero-s3-access"
  user_id      = var.user_ocid
}

# =============================================================================
# Quota Validation for Object Storage
# =============================================================================

# Free tier limit
locals {
  object_storage_free_tier_gb = 20
  velero_max_usage_gb         = 10 # Use only half of free tier for safety
}

# Quota check output
resource "null_resource" "object_storage_quota_check" {
  triggers = {
    max_usage = local.velero_max_usage_gb
    free_tier = local.object_storage_free_tier_gb
  }

  lifecycle {
    precondition {
      condition     = local.velero_max_usage_gb <= local.object_storage_free_tier_gb
      error_message = "Velero storage (${local.velero_max_usage_gb}GB) exceeds free tier (${local.object_storage_free_tier_gb}GB)"
    }
  }
}
