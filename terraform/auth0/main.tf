# =============================================================================
# Auth0 Main Module
# =============================================================================
# Reconstructs the GitOps state for the homelab authentication.

resource "auth0_organization" "homelab" {
  name         = "smadja-homelab"
  display_name = "Smadja Homelab"
}

module "roles" {
  source = "./modules/roles"
}

module "applications" {
  source = "./modules/applications"
}

locals {
  # Decode full user config from Doppler JSON
  # Format: {"username": {"email": "...", "name": "...", "nickname": "...", "password": "...", "roles": ["..."]}}
  # Use nonsensitive to allow for_each (the password is still used securely in the resource)
  doppler_users_raw = nonsensitive(data.doppler_secrets.this.map.AUTH0_USERS)
  doppler_users     = jsondecode(local.doppler_users_raw)

  # Use Doppler users if present, otherwise fall back to var.users (for dev mode)
  users = length(local.doppler_users) > 0 ? local.doppler_users : var.users
}

module "users" {
  source   = "./modules/users_org"
  users    = local.users
  org_id   = auth0_organization.homelab.id
  role_ids = module.roles.role_ids
}

# module "post_login_action" {
#   source = "./modules/action"
# }

# =============================================================================
# Export Cloudflare ID / Secret to Doppler
# =============================================================================

data "auth0_client" "cloudflare_access_data" {
  client_id = module.applications.applications["cloudflare_access"].client_id
}

data "auth0_client" "audiobookshelf_data" {
  client_id = module.applications.applications["audiobookshelf"].client_id
}

resource "doppler_secret" "auth0_cloudflare_client_id" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "AUTH0_CLOUDFLARE_CLIENT_ID"
  value   = module.applications.applications["cloudflare_access"].client_id
}

resource "doppler_secret" "auth0_cloudflare_client_secret" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "AUTH0_CLOUDFLARE_CLIENT_SECRET"
  value   = data.auth0_client.cloudflare_access_data.client_secret
}

resource "doppler_secret" "auth0_audiobookshelf_client_id" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "AUTH0_AUDIOBOOKSHELF_CLIENT_ID"
  value   = module.applications.applications["audiobookshelf"].client_id
}

resource "doppler_secret" "auth0_audiobookshelf_client_secret" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "AUTH0_AUDIOBOOKSHELF_CLIENT_SECRET"
  value   = data.auth0_client.audiobookshelf_data.client_secret
}
data "auth0_client" "vaultwarden_data" {
  client_id = module.applications.applications["vaultwarden"].client_id
}

resource "doppler_secret" "auth0_vaultwarden_client_id" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "AUTH0_VAULTWARDEN_CLIENT_ID"
  value   = module.applications.applications["vaultwarden"].client_id
}

resource "doppler_secret" "auth0_vaultwarden_client_secret" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "AUTH0_VAULTWARDEN_CLIENT_SECRET"
  value   = data.auth0_client.vaultwarden_data.client_secret
}
