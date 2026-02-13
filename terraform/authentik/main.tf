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
# Tokens - Create permanent token for Terraform/CI-CD using bootstrap token
# -----------------------------------------------------------------------------
# The bootstrap token (AUTHENTIK_BOOTSTRAP_TOKEN) is used to authenticate
# Terraform. We then create a permanent token for the akadmin user.
# -----------------------------------------------------------------------------

resource "authentik_token" "terraform_ci" {
  identifier   = "terraform-ci-token"
  user         = data.authentik_user.current.id
  description  = "Terraform CI/CD token - created automatically via GitHub Actions"
  intent       = "api"
  expiring     = false # Never expires
  retrieve_key = true  # Output the key
}

# Output the token for use in CI/CD
output "terraform_token" {
  description = "Terraform CI/CD token (save this to Doppler as AUTHENTIK_TOKEN)"
  value       = authentik_token.terraform_ci.key
  sensitive   = true
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
