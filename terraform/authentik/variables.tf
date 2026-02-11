# Optional: override URL/token via variables (otherwise use env)
variable "authentik_url" {
  type        = string
  default     = "https://auth.smadja.dev"
  description = "Authentik base URL (e.g. https://auth.smadja.dev). Override with TF_VAR_authentik_url or AUTHENTIK_URL in CI."
}

variable "authentik_token" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Authentik API token. Prefer AUTHENTIK_TOKEN env; never commit."
}

variable "oci_compartment_id" {
  description = "OCI compartment OCID where SMTP secrets are stored (from terraform/oracle-cloud outputs). If empty, use_global_settings=true."
  type        = string
  default     = ""
}

variable "oci_smtp_secret_names" {
  description = "OCI Vault secret names for SMTP configuration (defaults match vault-secrets.tf)"
  type = object({
    host     = string
    port     = string
    username = string
    password = string
    from     = string
  })
  default = {
    host     = "homelab-authentik-smtp-host"
    port     = "homelab-authentik-smtp-port"
    username = "homelab-authentik-smtp-username"
    password = "homelab-authentik-smtp-password"
    from     = "homelab-authentik-smtp-from"
  }
}
