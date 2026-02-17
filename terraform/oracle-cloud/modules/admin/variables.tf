variable "budget_alert_email" {
  description = "Email for budget alerts"
  type        = string
  default     = "smadjapaul02@gmail.com"
  sensitive   = true
}

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "tags" {
  description = "Freeform tags"
  type        = map(string)
  default     = {}
}
