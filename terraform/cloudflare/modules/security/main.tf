# =============================================================================
# Cloudflare Security — zone settings, WAF/rulesets
# =============================================================================

resource "cloudflare_zone_settings_override" "security" {
  count   = var.enable_zone_settings ? 1 : 0
  zone_id = var.zone_id

  settings {
    ssl                      = "strict"
    always_use_https         = "on"
    min_tls_version          = "1.2"
    tls_1_3                  = "on"
    automatic_https_rewrites = "on"
    security_level           = "medium"
    challenge_ttl            = 1800
    browser_check            = "on"
    privacy_pass             = "on"
    brotli                   = "on"
    browser_cache_ttl        = 14400
    cache_level              = "aggressive"
    http3                    = "on"
    zero_rtt                 = "on"
    websockets               = "on"

    security_header {
      enabled            = true
      include_subdomains = true
      max_age            = 31536000
      nosniff            = true
      preload            = true
    }

    early_hints         = "on"
    opportunistic_onion = "on"
    hotlink_protection  = "on"
  }
}

# Data source to check if rulesets already exist (only when needed)
data "cloudflare_rulesets" "existing" {
  count   = var.enable_geo_restriction || var.enable_authentik_api_skip_challenge ? 1 : 0
  zone_id = var.zone_id
}

locals {
  # Only check for existing rulesets if the data source was created
  rulesets = length(data.cloudflare_rulesets.existing) > 0 ? data.cloudflare_rulesets.existing[0].rulesets : []

  geo_ruleset_exists = var.enable_geo_restriction && length([
    for rs in local.rulesets : rs
    if rs.phase == "http_request_firewall_custom" && can(regex("[Gg]eo", rs.name))
  ]) > 0

  authentik_ruleset_exists = var.enable_authentik_api_skip_challenge && length([
    for rs in local.rulesets : rs
    if rs.phase == "http_config_settings" && can(regex("[Aa]uthentik", rs.name))
  ]) > 0
}

resource "cloudflare_ruleset" "geo_restrict" {
  count = var.enable_geo_restriction && length(var.allowed_countries) > 0 && !local.geo_ruleset_exists ? 1 : 0

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

resource "cloudflare_ruleset" "authentik_api_skip_challenge" {
  count = var.enable_authentik_api_skip_challenge && !local.authentik_ruleset_exists ? 1 : 0

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

locals {
  # Check if WAF skip ruleset already exists
  api_waf_skip_exists = var.enable_authentik_api_skip_challenge && length([
    for rs in local.rulesets : rs
    if rs.phase == "http_request_firewall_custom" && can(regex("[Aa]uthentik.*[Ss]kip", rs.name))
  ]) > 0
}

# WAF rule to skip all Cloudflare protections for Authentik API paths
# This is needed because http_config_settings doesn't disable Browser Integrity Check
resource "cloudflare_ruleset" "authentik_api_waf_skip" {
  count = var.enable_authentik_api_skip_challenge && !local.api_waf_skip_exists ? 1 : 0

  zone_id     = var.zone_id
  name        = "Authentik API - WAF skip"
  description = "Skip all WAF rules for auth.*/api/v3/* (allows Terraform/CI API calls)"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules {
    action      = "skip"
    description = "Skip all protections for Authentik API endpoints"
    expression  = "(http.host eq \"auth.${var.domain}\" and starts_with(http.request.uri.path, \"/api/v3/\"))"

    action_parameters {
      # Skip all WAF rules including Browser Integrity Check
      products = ["bic", "hot", "score", "sql", "xss", "uaBlock"]
    }
  }
}
