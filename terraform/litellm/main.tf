# =============================================================================
# LiteLLM — root module (credentials via child module)
# =============================================================================

module "credentials" {
  source = "./modules/credentials"

  openclaw_litellm_key = var.openclaw_litellm_key
}
