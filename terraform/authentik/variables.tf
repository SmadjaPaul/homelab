# authentik_url is declared in provider.tf (used by provider + locals)

variable "authentik_token" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Authentik API token. Prefer AUTHENTIK_TOKEN env; never commit."
}

variable "create_terraform_token" {
  type        = bool
  default     = true
  description = "Whether to create Terraform service account token"
}

variable "create_google_oauth2_provider" {
  type        = bool
  default     = true
  description = "Whether to create Google OAuth2 provider"
}

variable "google_oauth2_client_id" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Google OAuth2 client ID"
}

variable "google_oauth2_client_secret" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Google OAuth2 client secret"
}

variable "oci_compartment_id" {
  description = "[DEPRECATED] OCI compartment is no longer used. SMTP secrets now come from Doppler. Kept for backward compatibility."
  type        = string
  default     = ""
}

variable "oci_smtp_secret_names" {
  description = "[DEPRECATED] OCI Vault is no longer used. SMTP secrets now come from Doppler. Kept for backward compatibility."
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
# Slugs/noms des flows et certificat par défaut (data sources)
# Si ton instance a d'autres slugs (version différente ou config custom), override
# via TF_VAR_* ou terraform.tfvars. Pour trouver les slugs : Authentik → Flows →
# cliquer sur un flow → l'URL ou les détails affichent le slug.
# -----------------------------------------------------------------------------
variable "authentik_flow_slug_authorization" {
  type        = string
  default     = "default-provider-authorization-implicit-consent"
  description = "Slug du flow d'autorisation (provider) par défaut"
}

variable "authentik_flow_slug_invalidation" {
  type        = string
  default     = "default-provider-invalidation-flow"
  description = "Slug du flow d'invalidation (logout) par défaut"
}

variable "authentik_flow_slug_authentication" {
  type        = string
  default     = "default-authentication-flow"
  description = "Slug du flow d'authentification (login) par défaut"
}

variable "authentik_certificate_key_pair_name" {
  type        = string
  default     = "authentik Self-signed Certificate"
  description = "Nom du certificat par défaut (OIDC signing)"
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
    password    = optional(string, "") # bcrypt hash
  }))
  default = [
    {
      username    = "smadja-paul"
      name        = "Paul"
      email       = "smadja-paul@protonmail.com"
      group_names = ["admin", "family-validated"]
      is_active   = true
      path        = ""
      password    = "$2y$05$c9pCHpJgaoPWyRSPXg2bUeK4i5ksuXxoojsNuTAgQxLGIqV.CA9i." # PaulHomelab2026!
    }
  ]
  description = "Liste d'utilisateurs à créer. Pour importer un utilisateur existant: terraform import 'module.users[0].authentik_user.users[\"username\"]' <pk>."
}

# -----------------------------------------------------------------------------
# Google OAuth2 Configuration
# -----------------------------------------------------------------------------
variable "google_oauth2_provider" {
  type = object({
    name                   = string
    client_id              = string
    client_secret          = string
    authorization_flow     = string
    invalidation_flow      = string
    signing_key            = string
    access_token_validity  = string
    refresh_token_validity = string
    sub_mode               = string
    allowed_redirect_uris  = list(object({ url = string, matching_mode = string }))
  })
  default = {
    name                   = "Google OAuth2"
    client_id              = ""
    client_secret          = ""
    authorization_flow     = "default-provider-authorization-implicit-consent"
    invalidation_flow      = "default-provider-invalidation-flow"
    signing_key            = "authentik Self-signed Certificate"
    access_token_validity  = "hours=1"
    refresh_token_validity = "days=30"
    sub_mode               = "user_email"
    allowed_redirect_uris = [
      { url = "https://auth.smadja.dev/complete/google-oauth2/", matching_mode = "strict" }
    ]
  }
  description = "Google OAuth2 provider configuration"
}
