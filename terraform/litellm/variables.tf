variable "litellm_url" {
  type        = string
  description = "LiteLLM proxy base URL (e.g. https://llm.smadja.dev or http://litellm:4000 when running from same network)"
  default     = ""
}

variable "litellm_master_key" {
  type        = string
  sensitive   = true
  description = "LiteLLM master key for admin API. Prefer env LITELLM_MASTER_KEY; never commit."
  default     = ""
}
