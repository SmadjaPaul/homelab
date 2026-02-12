variable "oci_compartment_id" {
  type        = string
  default     = ""
  description = "OCI compartment for SMTP secrets; empty = use_global_settings"
}

variable "smtp_host" {
  type        = string
  default     = ""
  sensitive   = true
  description = "SMTP host from vault"
}

variable "smtp_port" {
  type        = string
  default     = "587"
  description = "SMTP port"
}

variable "smtp_username" {
  type        = string
  default     = ""
  sensitive   = true
  description = "SMTP username"
}

variable "smtp_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "SMTP password"
}

variable "smtp_from" {
  type        = string
  default     = "noreply@smadja.dev"
  description = "SMTP from address"
}

variable "default_authentication_flow_id" {
  type        = string
  description = "ID du flow d'authentification par défaut (pour policy reputation)"
}

variable "authentik_url" {
  type        = string
  default     = "https://auth.smadja.dev"
  description = "Base URL Authentik"
}

variable "authentik_token" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Token API Authentik (pour script link recovery)"
}

variable "link_recovery_script_path" {
  type        = string
  description = "Chemin absolu du script link-recovery-flow.sh (depuis la racine du repo)"
}
