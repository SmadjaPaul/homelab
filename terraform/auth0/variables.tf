variable "cloudflare_team" {
  type        = string
  description = "The Cloudflare access team name (subdomain of cloudflareaccess.com)"
}

variable "users" {
  description = "Users to create in Auth0"
  type        = any
  default     = {}
}
