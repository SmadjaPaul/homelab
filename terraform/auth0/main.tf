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

module "users" {
  source   = "./modules/users_org"
  users    = var.users
  org_id   = auth0_organization.homelab.id
  role_ids = module.roles.role_ids
}

module "post_login_action" {
  source = "./modules/action"
}

# =============================================================================
# Export Cloudflare ID / Secret to Doppler
# =============================================================================

data "auth0_client" "cloudflare_access_data" {
  client_id = module.applications.applications["cloudflare_access"].client_id
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
