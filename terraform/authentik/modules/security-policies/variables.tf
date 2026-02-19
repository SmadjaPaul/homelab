# =============================================================================
# Security Policies — Rate limiting, geo restriction, and advanced security
# =============================================================================

variable "enable_rate_limiting" {
  type        = bool
  default     = true
  description = "Activer les policies de rate limiting"
}

variable "enable_geo_restriction" {
  type        = bool
  default     = false
  description = "Activer les restrictions géographiques"
}

variable "allowed_countries" {
  type        = list(string)
  default     = ["FR", "BE", "CH", "LU"]
  description = "Liste des pays autorisés (codes ISO 3166-1 alpha-2)"
}

variable "rate_limit_attempts" {
  type        = number
  default     = 5
  description = "Nombre de tentatives avant blocage temporaire"
}

variable "rate_limit_window" {
  type        = string
  default     = "minutes=5"
  description = "Fenêtre de temps pour le rate limiting"
}
