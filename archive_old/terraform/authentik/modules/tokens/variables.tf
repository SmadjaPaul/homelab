# =============================================================================
# Tokens Variables
# =============================================================================

variable "create_service_account" {
  type        = bool
  default     = false
  description = "Create a service account for Terraform"
}

variable "token_identifier" {
  type        = string
  default     = "terraform-token"
  description = "Token identifier/name"
}

variable "user_id" {
  type        = number
  default     = null
  description = "User ID to associate token with (required if create_service_account=false)"
}

variable "superuser" {
  type        = bool
  default     = true
  description = "Create service account as superuser (requires admin access)"
}

variable "expires" {
  type        = string
  default     = ""
  description = "Expiration date (empty = never)"
}
