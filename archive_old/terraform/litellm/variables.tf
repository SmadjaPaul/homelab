variable "litellm_url" {
  type        = string
  description = "[DEPRECATED] LiteLLM URL now comes from Doppler. Kept for backward compatibility."
  default     = ""
}

variable "litellm_master_key" {
  type        = string
  sensitive   = true
  description = "[DEPRECATED] LiteLLM master key now comes from Doppler. Kept for backward compatibility."
  default     = ""
}

variable "openclaw_litellm_key" {
  type        = string
  sensitive   = true
  description = "[DEPRECATED] OpenClaw key now comes from Doppler. Kept for backward compatibility."
  default     = ""
}
