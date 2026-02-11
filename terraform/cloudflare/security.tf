# =============================================================================
# Cloudflare Security Settings
# =============================================================================

# SSL/TLS Configuration - Full (Strict) mode
resource "cloudflare_zone_settings_override" "security" {
  zone_id = var.zone_id

  settings {
    # SSL/TLS
    ssl                      = "strict"
    always_use_https         = "on"
    min_tls_version          = "1.2"
    tls_1_3                  = "on"
    automatic_https_rewrites = "on"

    # Security
    security_level = "medium"
    challenge_ttl  = 1800
    browser_check  = "on"
    privacy_pass   = "on"

    # Performance (minify not available on free tier via API)
    brotli = "on"

    # Caching
    browser_cache_ttl = 14400 # 4 hours
    cache_level       = "aggressive"

    # HTTP/3 and websockets (HTTP/2 is read-only on free tier)
    http3      = "on"
    zero_rtt   = "on"
    websockets = "on"

    # Security headers
    security_header {
      enabled            = true
      include_subdomains = true
      max_age            = 31536000 # 1 year
      nosniff            = true
      preload            = true
    }

    # Other
    early_hints         = "on"
    opportunistic_onion = "on"
    hotlink_protection  = "on"
  }
}

# Bot Fight Mode - Enable via Cloudflare Dashboard
# Dashboard > Security > Bots > Bot Fight Mode = ON

# =============================================================================
# Geo-restriction: allow traffic only from allowed countries (e.g. France)
# =============================================================================
# Block requests from IPs outside the allowed countries (ip.src.country).
# Free tier: zone-level custom rulesets are available. Only 5 rules allowed.

resource "cloudflare_ruleset" "geo_restrict" {
  count = var.enable_geo_restriction && length(var.allowed_countries) > 0 ? 1 : 0

  zone_id     = var.zone_id
  name        = "Homelab - Geo restriction (allow ${join(", ", var.allowed_countries)} only)"
  description = "Block traffic from countries not in allowed list"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules {
    action      = "block"
    description = "Block access from outside allowed countries"
    expression  = length(var.allowed_countries) == 1 ? "(ip.src.country ne \"${var.allowed_countries[0]}\")" : "(not ip.src.country in {${join(" ", formatlist("\"%s\"", var.allowed_countries))}})"
  }
}

# =============================================================================
# Authentik API: skip Cloudflare challenge for /api/* (Terraform/CI calls)
# =============================================================================
# Without this, requests from GitHub Actions (no browser) get "Just a moment..."
# and Terraform Authentik provider fails. We lower security for API paths only.
#
# By default (enable_authentik_api_skip_challenge = false) this ruleset is NOT
# created by Terraform, because the API token often lacks "Configuration Rules"
# permission. Create the rule once manually in the dashboard:
#
#   1. Cloudflare Dashboard → your zone (e.g. smadja.dev) → Security → Configuration Rules
#   2. Create rule: Name "Authentik API - skip challenge"
#   3. Expression: (http.host eq "auth.smadja.dev" and starts_with(http.request.uri.path, "/api/"))
#   4. Then: Configuration → Security Level → Essentially Off
#   5. Deploy
#
# If your token has Zone → Configuration Rules → Edit (or "Config Settings" Edit),
# set enable_authentik_api_skip_challenge = true so Terraform manages the rule.
# See: https://developers.cloudflare.com/rules/configuration-rules/create-api/
resource "cloudflare_ruleset" "authentik_api_skip_challenge" {
  count = var.enable_authentik_api_skip_challenge ? 1 : 0

  zone_id     = var.zone_id
  name        = "Authentik API - skip challenge"
  description = "Do not challenge requests to auth.*/api/ (allows Terraform/CI)"
  kind        = "zone"
  phase       = "http_config_settings"

  rules {
    action      = "set_config"
    description = "Lower security for Authentik API (Terraform/CI)"
    expression  = "(http.host eq \"auth.${var.domain}\" and starts_with(http.request.uri.path, \"/api/\"))"

    action_parameters {
      security_level = "essentially_off"
    }
  }
}

# WAF Custom Rules - Additional rules can be added via Dashboard (free tier limit: 5 rules)
# Dashboard > Security > WAF > Custom Rules
#
# Recommended rules to add manually:
# 1. Block vulnerability scanners:
#    Expression: (http.user_agent contains "sqlmap") or (http.user_agent contains "nikto")
#    Action: Block
#
# 2. Block sensitive paths:
#    Expression: (http.request.uri.path contains "/.env") or (http.request.uri.path contains "/.git")
#    Action: Block
