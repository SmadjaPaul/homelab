# =============================================================================
# Cloudflare Terraform — root module
# Domain: smadja.dev — DNS, Tunnel, Access, Security via child modules
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  backend "oci" {
    bucket    = "homelab-tfstate"
    namespace = "axnvxxurxefp"
    key       = "cloudflare/terraform.tfstate"
    region    = "eu-paris-1"
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "main" {
  zone_id = var.zone_id
}

# -----------------------------------------------------------------------------
# Tunnel (only when enable_tunnel = true)
# -----------------------------------------------------------------------------
module "tunnel" {
  source = "./modules/tunnel"
  count  = var.enable_tunnel ? 1 : 0

  account_id           = var.cloudflare_account_id
  tunnel_secret        = var.tunnel_secret
  tunnel_id            = var.tunnel_id
  domain               = var.domain
  proxmox_local_ip     = var.proxmox_local_ip
  enable_tunnel_config = var.enable_tunnel_config
}

# -----------------------------------------------------------------------------
# DNS (root, www, services, tunnel CNAMEs, OCI, SPF/DMARC)
# -----------------------------------------------------------------------------
module "dns" {
  source = "./modules/dns"

  zone_id           = var.zone_id
  domain            = var.domain
  enable_tunnel     = var.enable_tunnel
  homelab_services  = var.homelab_services
  tunnel_id         = var.enable_tunnel ? module.tunnel[0].tunnel_id : ""
  oci_management_ip = var.oci_management_ip
  oci_node_ips      = var.oci_node_ips
}

# -----------------------------------------------------------------------------
# Access — IdP Authentik + applications + policies (only when tunnel enabled)
# -----------------------------------------------------------------------------
module "access" {
  source = "./modules/access"
  count  = var.enable_tunnel ? 1 : 0

  account_id       = var.cloudflare_account_id
  domain           = var.domain
  homelab_services = var.homelab_services

  authentik_oidc_enabled       = var.authentik_oidc_enabled
  authentik_oidc_client_id     = var.authentik_oidc_client_id
  authentik_oidc_client_secret = var.authentik_oidc_client_secret
  authentik_oidc_auth_url      = var.authentik_oidc_auth_url
  authentik_oidc_token_url     = var.authentik_oidc_token_url
  authentik_oidc_certs_url     = var.authentik_oidc_certs_url
  allowed_emails               = var.allowed_emails
  skip_interstitial            = var.access_skip_interstitial
}

# -----------------------------------------------------------------------------
# Security — zone settings, geo restriction, Authentik API skip challenge
# -----------------------------------------------------------------------------
module "security" {
  source = "./modules/security"

  zone_id                             = var.zone_id
  domain                              = var.domain
  enable_zone_settings                = var.enable_zone_settings
  enable_geo_restriction              = var.enable_geo_restriction
  allowed_countries                   = var.allowed_countries
  enable_authentik_api_skip_challenge = var.enable_authentik_api_skip_challenge
}
