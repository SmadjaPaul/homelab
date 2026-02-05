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
    # Note: Bot Fight Mode cannot be disabled via API on free tier
    # To allow CI/CD access, use WAF rules to skip challenges for API paths

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
# WAF Rule: Allow API requests to Authentik (skip challenge for CI/CD)
# =============================================================================
# This rule allows GitHub Actions runners and other CI/CD tools to access
# Authentik API endpoints without Cloudflare's "Just a moment..." challenge.
# It skips security challenges for requests to Authentik API paths that include
# an Authorization header (indicating legitimate API access).
#
# Free tier: zone-level custom rulesets. Only 5 rules allowed total.
# This rule uses the "skip" action to bypass Cloudflare's managed security
# rules (challenges, bot protection) for authenticated API requests.

resource "cloudflare_ruleset" "allow_authentik_api" {
  count = var.enable_authentik_api_access ? 1 : 0

  zone_id     = var.zone_id
  name        = "Homelab - Allow Authentik API (CI/CD)"
  description = "Skip challenge for Authentik API requests with Authorization header (allows GitHub Actions CI/CD)"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules {
    action      = "skip"
    description = "Skip challenge for Authentik API requests (CI/CD access)"
    # Match: auth.smadja.dev + API paths + Authorization header present
    expression = "(http.host eq \"auth.${var.domain}\") and ((http.request.uri.path starts_with \"/api/v3/\") or (http.request.uri.path starts_with \"/application/o/\")) and (http.request.headers[\"Authorization\"] is not empty)"

    action_parameters {
      # Skip all remaining rules in the current ruleset
      # Note: To skip managed rulesets (challenges), we also need to exclude
      # these paths from geo_restriction (see below)
      ruleset = "current"
    }
  }
}

# =============================================================================
# Geo-restriction: allow traffic only from allowed countries (e.g. France)
# =============================================================================
# Block requests from IPs outside the allowed countries (ip.src.country).
# Free tier: zone-level custom rulesets are available. Only 5 rules allowed.
#
# IMPORTANT: This rule excludes Authentik API paths to allow CI/CD access
# from GitHub Actions runners (which may be in any country). The allow_authentik_api
# rule above handles skipping challenges, but we also need to exclude these paths
# from geo-blocking.

resource "cloudflare_ruleset" "geo_restrict" {
  count = var.enable_geo_restriction && length(var.allowed_countries) > 0 ? 1 : 0

  zone_id     = var.zone_id
  name        = "Homelab - Geo restriction (allow ${join(", ", var.allowed_countries)} only)"
  description = "Block traffic from countries not in allowed list (excludes Authentik API for CI/CD)"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules {
    action      = "block"
    description = "Block access from outside allowed countries (except Authentik API)"
    # Exclude auth.smadja.dev API paths from geo restriction (allow CI/CD from any country)
    # Expression: block if (NOT Authentik API path) AND (country not allowed)
    expression = "(not (http.host eq \"auth.${var.domain}\" and ((http.request.uri.path starts_with \"/api/v3/\") or (http.request.uri.path starts_with \"/application/o/\")))) and ${length(var.allowed_countries) == 1 ? "(ip.src.country ne \"${var.allowed_countries[0]}\")" : "(not ip.src.country in {${join(" ", formatlist("\"%s\"", var.allowed_countries))}})"}"
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
