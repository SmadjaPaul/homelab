output "openclaw_litellm_key" {
  description = "LiteLLM API key for OpenClaw. Set in OpenClaw config (e.g. LITELLM_API_KEY)."
  value       = module.credentials.openclaw_litellm_key
  sensitive   = true
}
