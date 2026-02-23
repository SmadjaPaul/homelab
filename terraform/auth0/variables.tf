variable "cloudflare_team" {
  type        = string
  description = "The Cloudflare access team name (subdomain of cloudflareaccess.com)"
  default     = "smadja"
}

variable "users" {
  description = "Users to create in Auth0"
  type        = any
  default     = {}
}

variable "doppler_token" {
  description = "Doppler API token for storing secrets"
  type        = string
  sensitive   = true
}
