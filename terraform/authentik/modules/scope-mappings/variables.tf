# =============================================================================
# Scope Mappings — For Cloudflare Access and OIDC providers
# =============================================================================

variable "create_cloudflare_access_mappings" {
  type        = bool
  default     = true
  description = "Créer les scope mappings pour Cloudflare Access"
}

variable "additional_claims" {
  type        = map(string)
  default     = {}
  description = "Claims additionnels à inclure dans les tokens"
}
