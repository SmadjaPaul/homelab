# =============================================================================
# Global config — read shared values from Doppler, expose as outputs
# Other modules receive these via root: domain = module.global_config.domain
# =============================================================================

data "doppler_secrets" "this" {
  project = var.doppler_project
  config  = var.doppler_environment
}
