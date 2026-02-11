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

variable "domain" {
  type        = string
  default     = "smadja.dev"
  description = "Public domain for external_host (e.g. omni.smadja.dev)"
}

variable "cloudflare_access_team" {
  type        = string
  default     = "smadja"
  description = "Cloudflare Access team subdomain (e.g. smadja for smadja.cloudflareaccess.com)"
}

# -----------------------------------------------------------------------------
# Users (optionnel) — Définir des utilisateurs dans Terraform (voir modules/users)
# -----------------------------------------------------------------------------
variable "authentik_users" {
  type = list(object({
    username    = string
    name        = string
    email       = optional(string, "")
    group_names = list(string)
    is_active   = optional(bool, true)
    path        = optional(string, "")
  }))
  default     = []
  description = "Liste d'utilisateurs à créer (optionnel). Préférer les invitations pour l'onboarding."
}
