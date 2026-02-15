# Cloudflare Cache Rules for Comet
# Optimizes caching for Stremio addon responses
# Prevents caching of dynamic/streaming content while caching static assets

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

variable "zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "domain" {
  description = "Root domain"
  type        = string
}

variable "enable_comet_cache_rules" {
  description = "Enable Cloudflare cache rules for Comet"
  type        = bool
  default     = false
}

locals {
  comet_host = "stream.${var.domain}"
}

# Cache Rule: Bypass cache for API endpoints
resource "cloudflare_ruleset" "comet_api_bypass" {
  count = var.enable_comet_cache_rules ? 1 : 0

  zone_id     = var.zone_id
  name        = "Comet API - Bypass Cache"
  description = "Disable caching for Comet API endpoints to ensure fresh responses"
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules {
    action      = "set_cache_settings"
    description = "Bypass cache for Comet API endpoints"
    expression  = "(http.host eq \"${local.comet_host}\" and (http.request.uri.path contains \"/search\" or http.request.uri.path contains \"/catalog\" or http.request.uri.path contains \"/stream\"))"
    enabled     = true

    action_parameters {
      cache = false
    }
  }
}

# Cache Rule: Cache static assets (manifest.json)
resource "cloudflare_ruleset" "comet_static_cache" {
  count = var.enable_comet_cache_rules ? 1 : 0

  zone_id     = var.zone_id
  name        = "Comet Static - Cache"
  description = "Cache Comet static assets (manifest.json)"
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules {
    action      = "set_cache_settings"
    description = "Cache Comet manifest.json"
    expression  = "(http.host eq \"${local.comet_host}\" and (http.request.uri.path eq \"/manifest.json\" or http.request.uri.path eq \"/\"))"
    enabled     = true

    action_parameters {
      cache = true
      edge_ttl {
        mode    = "override_origin"
        default = 3600 # 1 hour
      }
      browser_ttl {
        mode    = "override_origin"
        default = 3600 # 1 hour
      }
    }
  }
}

# WAF Rule: Rate limiting for Comet
resource "cloudflare_ruleset" "comet_rate_limit" {
  count = var.enable_comet_cache_rules ? 1 : 0

  zone_id     = var.zone_id
  name        = "Comet Rate Limiting"
  description = "Rate limiting for Comet to prevent abuse"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules {
    action      = "block"
    description = "Rate limit excessive requests to Comet"
    expression  = "(http.host eq \"${local.comet_host}\" and ip.geoip.country ne \"FR\")"
    enabled     = true
  }
}

# Output for reference
output "comet_cache_rules_enabled" {
  description = "Whether Comet cache rules are enabled"
  value       = var.enable_comet_cache_rules
}
