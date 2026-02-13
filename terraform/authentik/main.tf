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
# Apps — Proxy (Omni, LiteLLM, OpenClaw, Odoo), OIDC, Cloudflare Access, Outpost
# -----------------------------------------------------------------------------
module "apps" {
  source = "./modules/apps"

  default_authorization_flow_id   = data.authentik_flow.default_authorization_flow.id
  default_invalidation_flow_id    = data.authentik_flow.default_invalidation.id
  default_certificate_key_pair_id = data.authentik_certificate_key_pair.default.id
  authentik_url                   = var.authentik_url
  domain                          = var.domain
  cloudflare_access_team          = var.cloudflare_access_team
  default_oidc_scope_mapping_ids  = local.default_oidc_scope_mapping_ids
}
