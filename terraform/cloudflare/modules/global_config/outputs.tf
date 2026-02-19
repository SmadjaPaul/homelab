# =============================================================================
# Global config — outputs for use in root and by other modules
# =============================================================================

output "domain" {
  description = "Root domain (from Doppler DOMAIN)"
  value       = data.doppler_secrets.this.map.DOMAIN
}

output "zone_id" {
  description = "Cloudflare Zone ID (from Doppler CLOUDFLARE_ZONE_ID)"
  value       = data.doppler_secrets.this.map.CLOUDFLARE_ZONE_ID
}

output "cloudflare_account_id" {
  description = "Cloudflare Account ID (from Doppler)"
  value       = data.doppler_secrets.this.map.CLOUDFLARE_ACCOUNT_ID
}

output "cloudflare_api_token" {
  description = "Cloudflare API token for provider (from Doppler)"
  value       = data.doppler_secrets.this.map.CLOUDFLARE_API_TOKEN
  sensitive   = true
}

output "existing_tunnel_id" {
  description = "Existing Cloudflare Tunnel ID from Doppler (empty if creating new)"
  value       = data.doppler_secrets.this.map.CLOUDFLARE_TUNNEL_ID
}

output "existing_tunnel_secret" {
  description = "Existing Cloudflare Tunnel secret from Doppler"
  value       = data.doppler_secrets.this.map.CLOUDFLARE_TUNNEL_SECRET
  sensitive   = true
}

output "enable_zone_settings" {
  description = "Whether to manage zone SSL/HSTS settings (from Doppler ENABLE_ZONE_SETTINGS)"
  value       = data.doppler_secrets.this.map.ENABLE_ZONE_SETTINGS == "true"
}

output "enable_geo_restriction" {
  description = "Whether to enable WAF geo restriction (from Doppler ENABLE_GEO_RESTRICTION)"
  value       = data.doppler_secrets.this.map.ENABLE_GEO_RESTRICTION == "true"
}

output "enable_authentik_api_skip_challenge" {
  description = "Skip challenge for auth.*/api/* (from Doppler ENABLE_API_SKIP_CHALLENGE)"
  value       = data.doppler_secrets.this.map.ENABLE_API_SKIP_CHALLENGE == "true"
}
