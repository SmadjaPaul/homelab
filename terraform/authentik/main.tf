# =============================================================================
# Authentik — Root module (IaC for groups, policies, and users)
# =============================================================================
# Configures:
# - Groups: admin, family-validated
# - Policies: expression policies for access control
# - Users: managed users (groups managed manually in UI)
# =============================================================================

module "groups" {
  source = "./modules/groups"
}

module "policies" {
  source = "./modules/policies"
}

module "users" {
  source = "./modules/users"
  count  = length(var.authentik_users) > 0 ? 1 : 0

  users             = var.authentik_users
  group_ids_by_name = module.groups.group_ids_by_name
}

# -----------------------------------------------------------------------------
# Tokens - Create service account token for Terraform/CI-CD
# -----------------------------------------------------------------------------
module "tokens" {
  source = "./modules/tokens"
  count  = var.create_terraform_token ? 1 : 0

  create_service_account = true
  token_identifier       = "terraform-$(timestamp())"
  superuser              = true
}

# -----------------------------------------------------------------------------
# Google OAuth2 Provider (Social Login)
# -----------------------------------------------------------------------------
module "google_oauth2" {
  source = "./modules/apps"
  count  = var.create_google_oauth2_provider ? 1 : 0

  google_oauth2_provider = {
    name                   = "Google OAuth2"
    client_id              = var.google_oauth2_client_id
    client_secret          = var.google_oauth2_client_secret
    authorization_flow     = var.default_authorization_flow_id
    invalidation_flow      = var.default_invalidation_flow_id
    signing_key            = var.default_certificate_key_pair_id
    access_token_validity  = "hours=1"
    refresh_token_validity = "days=30"
    sub_mode               = "user_email"
    allowed_redirect_uris = [
      { url = "${var.authentik_url}/complete/google-oauth2/", matching_mode = "strict" }
    ]
  }
}
