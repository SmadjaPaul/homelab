# =============================================================================
# SMTP Secrets from Doppler
# =============================================================================
# Reads SMTP configuration secrets from Doppler to configure Authentik email stage.
# Secrets are managed in the "authentik" Doppler project.
#
# Usage:
#   - Set DOPPLER_TOKEN environment variable or use Doppler CLI login
#   - Secrets are accessed via data.doppler_secrets.authentik.map
# =============================================================================

# Doppler provider - uses DOPPLER_TOKEN env var
# The provider is configured in provider.tf

# Fetch SMTP secrets from Doppler
data "doppler_secrets" "authentik_smtp" {
  project = "authentik"
  config  = "prd"
}

# Local values for SMTP configuration
locals {
  # SMTP configuration from Doppler
  smtp_host     = try(data.doppler_secrets.authentik_smtp.map.SMTP_HOST, "")
  smtp_port     = try(data.doppler_secrets.authentik_smtp.map.SMTP_PORT, "587")
  smtp_username = try(data.doppler_secrets.authentik_smtp.map.SMTP_USERNAME, "")
  smtp_password = try(data.doppler_secrets.authentik_smtp.map.SMTP_PASSWORD, "")
  smtp_from     = try(data.doppler_secrets.authentik_smtp.map.SMTP_FROM, "noreply@smadja.dev")

  # Flag to determine if SMTP is configured
  smtp_configured = local.smtp_host != "" && local.smtp_username != "" && local.smtp_password != ""
}
