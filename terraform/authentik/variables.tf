# Optional: override URL/token via variables (otherwise use env)
variable "authentik_url" {
  type        = string
  default     = ""
  description = "Authentik base URL (e.g. https://authentik.example.com). Prefer AUTHENTIK_URL env."
}

variable "authentik_token" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Authentik API token. Prefer AUTHENTIK_TOKEN env; never commit."
}
