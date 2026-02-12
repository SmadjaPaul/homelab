# OpenClaw — dedicated API key for LiteLLM proxy
resource "litellm_key" "openclaw" {
  key_alias = "openclaw"
  key       = var.openclaw_litellm_key != "" ? var.openclaw_litellm_key : null
}
