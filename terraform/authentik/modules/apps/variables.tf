variable "domain" {
  type        = string
  default     = "smadja.dev"
  description = "Public domain for external_host (e.g. omni.smadja.dev)"
}

variable "default_authorization_flow_id" {
  type        = string
  description = "ID du flow d'autorisation par défaut"
}

variable "default_invalidation_flow_id" {
  type        = string
  description = "ID du flow d'invalidation par défaut"
}

variable "default_certificate_key_pair_id" {
  type        = string
  description = "ID du certificat par défaut (signing key OIDC)"
}

variable "authentik_url" {
  type        = string
  default     = "https://auth.smadja.dev"
  description = "Base URL Authentik"
}

variable "cloudflare_access_team" {
  type        = string
  default     = "smadja"
  description = "Cloudflare Access team subdomain (e.g. smadja for smadja.cloudflareaccess.com)"
}

variable "default_oidc_scope_mapping_ids" {
  type        = list(string)
  default     = []
  description = "Scope mapping IDs (openid, email, profile) so OIDC IdPs get user info; required for Cloudflare Access"
}
