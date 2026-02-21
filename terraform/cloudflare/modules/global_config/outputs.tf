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

# =============================================================================
# Auth0 Configuration
# =============================================================================

output "auth0_domain" {
  description = "Auth0 domain (from Doppler AUTH0_DOMAIN)"
  value       = data.doppler_secrets.this.map.AUTH0_DOMAIN
}

output "auth0_cloudflare_client_id" {
  description = "Auth0 client ID for Cloudflare Access (from Doppler)"
  value       = data.doppler_secrets.this.map.AUTH0_CLOUDFLARE_CLIENT_ID
}

output "auth0_cloudflare_client_secret" {
  description = "Auth0 client secret for Cloudflare Access (from Doppler)"
  value       = data.doppler_secrets.this.map.AUTH0_CLOUDFLARE_CLIENT_SECRET
  sensitive   = true
}
