# =============================================================================
# Security module — zone settings, rulesets
# =============================================================================

variable "zone_id" {
  type        = string
  description = "Cloudflare Zone ID"
}

variable "domain" {
  type        = string
  description = "Root domain (e.g. for Authentik API rule)"
}

variable "enable_zone_settings" {
  type        = bool
  description = "Manage zone SSL/HSTS/etc. Set false if token lacks Zone Settings"
  default     = true
}

variable "enable_geo_restriction" {
  type        = bool
  description = "Create WAF rule to block traffic from countries not in allowed_countries"
  default     = true
}

variable "allowed_countries" {
  type        = list(string)
  description = "Country codes to allow (e.g. [\"FR\"]). Empty = no geo rule."
  default     = []
}

variable "enable_authentik_api_skip_challenge" {
  type        = bool
  description = "Create Configuration Rule to skip challenge for auth.*/api/*"
  default     = false
}
