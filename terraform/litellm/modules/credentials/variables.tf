variable "openclaw_litellm_key" {
  type        = string
  sensitive   = true
  description = "Optional API key for OpenClaw. If empty, LiteLLM generates one."
  default     = ""
}
