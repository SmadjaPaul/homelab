# =============================================================================
# Cloudflare Terraform — root module
# Domain: smadja.dev — DNS, Tunnel, Access, Security via child modules
# Secrets sourced from Doppler
# =============================================================================

terraform {
  required_version = ">= 1.12"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    doppler = {
      source  = "DopplerHQ/doppler"
      version = ">= 1.0"
    }
  }
}

provider "cloudflare" {
  api_token = module.global_config.cloudflare_api_token
}

provider "doppler" {
  doppler_token = var.doppler_token
}

# Centralised config: Doppler secrets exposed as outputs for all modules
module "global_config" {
  source = "./modules/global_config"

  doppler_project     = var.doppler_project
  doppler_environment = var.doppler_environment
}

data "cloudflare_zone" "main" {
  zone_id = module.global_config.zone_id
}

# -----------------------------------------------------------------------------
# Tunnel - use existing from Doppler or create new, then update secrets
# -----------------------------------------------------------------------------
module "tunnel" {
  source = "./modules/tunnel"
  count  = var.enable_tunnel ? 1 : 0

  depends_on = [module.global_config]

  account_id           = module.global_config.cloudflare_account_id
  tunnel_secret        = local.existing_tunnel_secret
  tunnel_id            = local.tunnel_id_to_pass
  domain               = module.global_config.domain
  proxmox_local_ip     = var.proxmox_local_ip
  enable_tunnel_config = var.enable_tunnel_config
  regenerate           = var.regenerate_tunnel_credentials
}

# Determine the actual tunnel ID and secret to use
# Always sync to Doppler - whether creating new or using existing
locals {
  # Get tunnel values - use module output if tunnel was created, otherwise use existing from Doppler
  current_tunnel_id     = var.enable_tunnel ? coalesce(module.tunnel[0].tunnel_id, local.existing_tunnel_id) : local.existing_tunnel_id
  current_tunnel_secret = var.enable_tunnel ? coalesce(module.tunnel[0].tunnel_token, local.existing_tunnel_secret) : local.existing_tunnel_secret
}

# Update Doppler secrets with tunnel credentials - ALWAYS run to keep in sync
resource "doppler_secret" "tunnel_id" {
  count   = local.current_tunnel_id != "" ? 1 : 0
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "CLOUDFLARE_TUNNEL_ID"
  value   = local.current_tunnel_id
}

resource "doppler_secret" "tunnel_secret" {
  count   = local.current_tunnel_secret != "" ? 1 : 0
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "CLOUDFLARE_TUNNEL_SECRET"
  value   = local.current_tunnel_secret
}

resource "doppler_secret" "tunnel_token" {
  count   = local.current_tunnel_id != "" ? 1 : 0
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "CLOUDFLARE_TUNNEL_TOKEN"
  value = jsonencode({
    AccountTag   = module.global_config.cloudflare_account_id
    TunnelID     = local.current_tunnel_id
    TunnelSecret = local.current_tunnel_secret
  })
}

# -----------------------------------------------------------------------------
# DNS (root, www, email/MX, SPF/DMARC - infrastructure only)
# Application DNS managed by external-dns in Kubernetes
# -----------------------------------------------------------------------------
module "dns" {
  source = "./modules/dns"

  depends_on = [module.global_config]

  zone_id              = module.global_config.zone_id
  domain               = module.global_config.domain
  enable_tunnel        = var.enable_tunnel
  homelab_services     = var.homelab_services
  oci_management_ip    = var.oci_management_ip
  create_root_record   = var.create_root_record
  enable_stream_record = var.enable_stream_record
}

# -----------------------------------------------------------------------------
# Access — Auth0 IdP + applications + policies (only when tunnel enabled and access enabled)
# -----------------------------------------------------------------------------
module "access" {
  source = "./modules/access"
  count  = var.enable_tunnel && var.enable_access ? 1 : 0

  depends_on = [module.global_config]

  account_id       = module.global_config.cloudflare_account_id
  domain           = module.global_config.domain
  homelab_services = var.homelab_services

  # Auth0 IdP (from Doppler via global_config)
  auth0_oidc_enabled       = var.auth0_oidc_enabled
  auth0_oidc_client_id     = var.auth0_oidc_enabled ? module.global_config.auth0_cloudflare_client_id : ""
  auth0_oidc_client_secret = var.auth0_oidc_enabled ? module.global_config.auth0_cloudflare_client_secret : ""
  auth0_domain             = var.auth0_oidc_enabled ? module.global_config.auth0_domain : ""

  allowed_emails    = var.allowed_emails
  skip_interstitial = var.access_skip_interstitial
  bypass_ips        = var.access_bypass_ips
  role_access       = var.role_access
}

# -----------------------------------------------------------------------------
# Security — zone settings, geo restriction
# -----------------------------------------------------------------------------
module "security" {
  source = "./modules/security"

  depends_on = [module.global_config]

  zone_id                = module.global_config.zone_id
  domain                 = module.global_config.domain
  enable_zone_settings   = module.global_config.enable_zone_settings
  enable_geo_restriction = module.global_config.enable_geo_restriction
  allowed_countries      = var.allowed_countries
}

# -----------------------------------------------------------------------------
# Comet Cache Rules — optimize caching for streaming service
# -----------------------------------------------------------------------------
module "comet_cache" {
  source = "./modules/comet-cache-rules"
  count  = var.enable_comet_cache_rules ? 1 : 0

  depends_on = [module.global_config]

  zone_id                  = module.global_config.zone_id
  domain                   = module.global_config.domain
  enable_comet_cache_rules = var.enable_comet_cache_rules
}
