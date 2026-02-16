variable "admin_only_policy_id" {
  type        = string
  description = "ID de la policy admin_only"
}

variable "omni_application_uuid" {
  type        = string
  description = "UUID de l'application Omni"
}

variable "litellm_application_uuid" {
  type        = string
  description = "UUID de l'application LiteLLM"
}

variable "openclaw_application_uuid" {
  type        = string
  description = "UUID de l'application OpenClaw"
}

variable "openclaw_oidc_application_uuid" {
  type        = string
  description = "UUID de l'application OpenClaw OIDC"
}

variable "odoo_application_uuid" {
  type        = string
  description = "UUID de l'application Odoo"
}

variable "professionnelle_only_policy_id" {
  type        = string
  description = "ID de la policy professionnelle_only"
}
