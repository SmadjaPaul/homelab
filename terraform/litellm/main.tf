# =============================================================================
# LiteLLM — root module (credentials via child module)
# Secrets are retrieved from Doppler
# =============================================================================

module "credentials" {
  source = "./modules/credentials"

  # OpenClaw API key from Doppler (optional, generates new if not set)
  openclaw_litellm_key = try(data.doppler_secrets.litellm.map.OPENCLAW_LITELLM_KEY, "")
}
