# Object Storage Module Variables

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
  default     = "ocid1.tenancy.oc1..aaaaaaaamwy5a55i2ljjxildejy42z2zshzs3edjbevyl27q4iv52sqqaqna"
}

variable "namespace" {
  description = "Object Storage namespace"
  type        = string
  default     = "axnvxxurxefp"
}

variable "bucket_name" {
  description = "Bucket name"
  type        = string
  default     = "homelab-tfstate"
}

variable "tags" {
  description = "Freeform tags"
  type        = map(string)
  default     = {}
}

variable "version_retention_days" {
  description = "Nombre de jours avant suppression des anciennes versions d'objets (limite indirecte du nombre de versions)"
  type        = number
  default     = 20
}
