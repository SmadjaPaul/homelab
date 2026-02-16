# Network Module Variables

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "vcn_name" {
  description = "VCN name prefix"
  type        = string
  default     = "homelab"
}

variable "vcn_cidr" {
  description = "VCN CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR (for OKE workers)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "tags" {
  description = "Freeform tags"
  type        = map(string)
  default     = {}
}
