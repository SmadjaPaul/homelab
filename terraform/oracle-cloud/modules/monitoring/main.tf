# =============================================================================
# OCI Monitoring & Logging Module
# Free Tier: 10GB logging storage
# =============================================================================

# OCI Log Group for OKE
resource "oci_logging_log_group" "oke_logs" {
  compartment_id = var.compartment_id
  display_name   = "${var.prefix}-oke-logs"
  description    = "Log group for OKE cluster and nodes"

  freeform_tags = var.tags
}

# =============================================================================
# Outputs
# =============================================================================

output "log_group_id" {
  value = oci_logging_log_group.oke_logs.id
}

output "log_group_ocid" {
  description = "Full OCID of the log group"
  value       = oci_logging_log_group.oke_logs.id
}
