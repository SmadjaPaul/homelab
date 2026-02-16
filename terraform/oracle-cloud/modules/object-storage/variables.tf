# Object Storage Module Variables

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "namespace" {
  description = "Object Storage namespace"
  type        = string
}

variable "bucket_name" {
  description = "Bucket name"
  type        = string
  default     = "terraform-states"
}

variable "tags" {
  description = "Freeform tags"
  type        = map(string)
  default     = {}
}
