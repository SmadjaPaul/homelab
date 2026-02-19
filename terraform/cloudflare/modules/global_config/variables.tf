# =============================================================================
# Global config — inputs (Doppler project/config; provider is inherited from root)
# =============================================================================

variable "doppler_project" {
  description = "Doppler project name"
  type        = string
}

variable "doppler_environment" {
  description = "Doppler environment (config)"
  type        = string
}
