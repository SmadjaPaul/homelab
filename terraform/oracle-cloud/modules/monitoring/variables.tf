# =============================================================================
# Monitoring Module Variables
# =============================================================================

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "homelab"
}

variable "tags" {
  description = "Freeform tags"
  type        = map(string)
  default     = {}
}
