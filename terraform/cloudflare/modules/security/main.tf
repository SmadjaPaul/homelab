# =============================================================================
# Cloudflare Security — zone settings, WAF/rulesets
# =============================================================================

locals {
  settings = {
    ssl                      = "strict"
    always_use_https         = "on"
    min_tls_version          = "1.2"
    tls_1_3                  = "on"
    automatic_https_rewrites = "on"
    security_level           = "medium"
    challenge_ttl            = "1800"
    browser_check            = "on"
    privacy_pass             = "on"
    brotli                   = "on"
    # browser_cache_ttl        = "14400"
    cache_level = "aggressive"
    http3       = "on"
    # zero_rtt                 = "on"
    websockets          = "on"
    early_hints         = "on"
    opportunistic_onion = "on"
    hotlink_protection  = "on"
  }
}

resource "cloudflare_zone_setting" "security" {
  for_each   = nonsensitive(var.enable_zone_settings) ? local.settings : {}
  zone_id    = var.zone_id
  setting_id = each.key
  value      = each.value
}

# Data source to check if rulesets already exist (only when needed)
data "cloudflare_rulesets" "existing" {
  count   = var.enable_geo_restriction ? 1 : 0
  zone_id = var.zone_id
}

locals {
  # Only check for existing rulesets if the data source was created
  rulesets = length(data.cloudflare_rulesets.existing) > 0 ? data.cloudflare_rulesets.existing[0].rulesets : []

  geo_ruleset_exists = var.enable_geo_restriction && length([
    for rs in local.rulesets : rs
    if rs.phase == "http_request_firewall_custom" && can(regex("[Gg]eo", rs.name))
  ]) > 0
}

resource "cloudflare_ruleset" "geo_restrict" {
  count = var.enable_geo_restriction && length(var.allowed_countries) > 0 && !local.geo_ruleset_exists ? 1 : 0

  zone_id     = var.zone_id
  name        = "Homelab - Geo restriction (allow ${join(", ", var.allowed_countries)} only)"
  description = "Block traffic from countries not in allowed list"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules = [{
    action      = "block"
    description = "Block access from outside allowed countries"
    expression  = length(var.allowed_countries) == 1 ? "(ip.src.country ne \"${var.allowed_countries[0]}\")" : "(not ip.src.country in {${join(" ", formatlist("\"%s\"", var.allowed_countries))}})"
  }]
}
