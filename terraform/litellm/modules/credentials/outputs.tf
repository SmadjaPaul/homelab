output "openclaw_litellm_key" {
  description = "LiteLLM API key for OpenClaw (set in OpenClaw config as LITELLM_API_KEY)"
  value       = litellm_key.openclaw.key
  sensitive   = true
}
