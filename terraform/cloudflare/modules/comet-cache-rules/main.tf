# Cloudflare Cache Rules for Comet - Official Documentation Implementation
# Source: https://github.com/g0ldyy/comet/blob/main/deployment/cloudflare-cache-rules.md

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
  description = "Enable Cloudflare cache rules for Comet per official documentation"
  type        = bool
  default     = false
}

locals {
  comet_host = "stream.${var.domain}"
}

# =============================================================================
# 1. Streams Cache Rule
# Cache all stream results. Comet controls the TTL via headers.
# Rule Name: Streams
# Expression: (http.request.uri.path contains "/stream/")
# Action: Eligible for Cache
# Edge TTL: Use cache-control header if present (first option)
# Browser TTL: Respect origin
# Serve stale content while revalidating: On
# =============================================================================
resource "cloudflare_ruleset" "comet_streams_cache" {
  count = var.enable_comet_cache_rules ? 1 : 0

  zone_id     = var.zone_id
  name        = "Comet - Streams"
  description = "Cache all stream results. Comet controls the TTL via headers."
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules {
    action      = "set_cache_settings"
    description = "Cache stream results with header-based TTL"
    expression  = "(http.host eq \"${local.comet_host}\" and http.request.uri.path contains \"/stream/\")"
    enabled     = true

    action_parameters {
      cache = true

      edge_ttl {
        mode = "respect_origin"
      }

      browser_ttl {
        mode = "respect_origin"
      }

      serve_stale {
        disable_stale_while_updating = false
      }
    }
  }
}

# =============================================================================
# 2. Configure Page Cache Rule
# Cache the configuration page.
# Rule Name: Configure Page
# Expression: (http.request.uri.path eq "/configure")
# Action: Eligible for Cache
# Edge TTL: Use cache-control header if present (first option)
# Browser TTL: Respect origin
# Serve stale content while revalidating: On
# =============================================================================
resource "cloudflare_ruleset" "comet_configure_cache" {
  count = var.enable_comet_cache_rules ? 1 : 0

  zone_id     = var.zone_id
  name        = "Comet - Configure Page"
  description = "Cache the configuration page"
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules {
    action      = "set_cache_settings"
    description = "Cache configure page with header-based TTL"
    expression  = "(http.host eq \"${local.comet_host}\" and http.request.uri.path eq \"/configure\")"
    enabled     = true

    action_parameters {
      cache = true

      edge_ttl {
        mode = "respect_origin"
      }

      browser_ttl {
        mode = "respect_origin"
      }

      serve_stale {
        disable_stale_while_updating = false
      }
    }
  }
}

# =============================================================================
# 3. Manifest Cache Rule
# Cache the add-on manifest.
# Rule Name: Manifest
# Expression: (http.request.uri.path contains "/manifest.json")
# Action: Eligible for Cache
# Edge TTL: Use cache-control header if present (first option)
# Browser TTL: Respect origin
# Serve stale content while revalidating: On
# =============================================================================
resource "cloudflare_ruleset" "comet_manifest_cache" {
  count = var.enable_comet_cache_rules ? 1 : 0

  zone_id     = var.zone_id
  name        = "Comet - Manifest"
  description = "Cache the add-on manifest"
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules {
    action      = "set_cache_settings"
    description = "Cache manifest.json with header-based TTL"
    expression  = "(http.host eq \"${local.comet_host}\" and http.request.uri.path contains \"/manifest.json\")"
    enabled     = true

    action_parameters {
      cache = true

      edge_ttl {
        mode = "respect_origin"
      }

      browser_ttl {
        mode = "respect_origin"
      }

      serve_stale {
        disable_stale_while_updating = false
      }
    }
  }
}

# =============================================================================
# 4. Tiered Cache
# Enable Tiered Cache in Caching > Tiered Cache.
# This minimizes requests to your origin by checking other Cloudflare datacenters first.
# Note: This is configured at account level, not via rulesets
# =============================================================================
# Tiered Cache is enabled via cloudflare_tiered_cache resource or manually in dashboard
# Not available in rulesets, see: https://developers.cloudflare.com/cache/how-to/tiered-cache/

# =============================================================================
# 5. Network Optimizations
# HTTP/3 (QUIC): On (faster connections, especially on mobile)
# 0-RTT Connection Resumption: On (reduces latency for repeat visitors)
# These are zone settings, configured in zone_settings_override
# =============================================================================

# Additional: API endpoints should NOT be cached
resource "cloudflare_ruleset" "comet_api_bypass" {
  count = var.enable_comet_cache_rules ? 1 : 0

  zone_id     = var.zone_id
  name        = "Comet - API Bypass"
  description = "Do not cache API endpoints (search, catalog)"
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules {
    action      = "set_cache_settings"
    description = "Bypass cache for API endpoints"
    expression  = "(http.host eq \"${local.comet_host}\" and (http.request.uri.path contains \"/search\" or http.request.uri.path contains \"/catalog\"))"
    enabled     = true

    action_parameters {
      cache = false
    }
  }
}

# Output for verification
output "comet_cache_rules_summary" {
  description = "Summary of Comet cache rules created"
  value = var.enable_comet_cache_rules ? {
    streams_cache_enabled   = true
    configure_cache_enabled = true
    manifest_cache_enabled  = true
    api_bypass_enabled      = true
    note                    = "Tiered Cache and Network Optimizations (HTTP/3, 0-RTT) must be enabled manually in Cloudflare dashboard"
    } : {
    enabled = false
  }
}
