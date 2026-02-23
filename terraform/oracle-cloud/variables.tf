# =============================================================================
# Oracle Cloud - Variables (single place for tfvars compatibility & stability)
# Align with archive_old pattern: all variables declared here, not in main.tf
# =============================================================================

variable "region" {
  description = "OCI Region"
  type        = string
  default     = "eu-paris-1"
}

variable "tenancy_ocid" {
  description = "OCI Tenancy OCID (fallback - also checks OCI_TENANCY_OCID env var)"
  type        = string
  default     = ""
}

variable "user_ocid" {
  description = "OCI User OCID (fallback - also checks OCI_USER_OCID env var)"
  type        = string
  default     = ""
}

variable "oci_fingerprint" {
  description = "OCI API Key Fingerprint (fallback)"
  type        = string
  default     = ""
}

variable "oci_private_key" {
  description = "OCI API Private Key Content (fallback)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "doppler_token" {
  description = "Doppler token for secrets"
  type        = string
  sensitive   = true
}

variable "compartment_id" {
  description = "OCI Compartment OCID"
  default     = "ocid1.tenancy.oc1..aaaaaaaamwy5a55i2ljjxildejy42z2zshzs3edjbevyl27q4iv52sqqaqna"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for worker nodes / instances"
  type        = string
  default     = ""
  sensitive   = true
}

variable "kubernetes_version" {
  description = "Kubernetes version for OKE"
  type        = string
  default     = "v1.31.10"
}
