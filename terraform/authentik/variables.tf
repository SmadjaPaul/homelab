variable "doppler_token" {
  type        = string
  description = "Doppler token for fetching secrets"
}

variable "authentik_url" {
  type        = string
  default     = "http://127.0.0.1:9000"
  description = "Authentik API URL"
}

variable "authentik_token" {
  type        = string
  sensitive   = true
  description = "Authentik API Token"
}
