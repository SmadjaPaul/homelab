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

module "scope_mappings" {
  source = "./modules/scope-mappings"

  create_cloudflare_access_mappings = true
  additional_claims = {
    environment = "production"
    tenant      = "homelab"
  }
}

module "security_policies" {
  source = "./modules/security-policies"

  enable_rate_limiting   = true
  enable_geo_restriction = false # À activer si besoin
  rate_limit_attempts    = 5
  allowed_countries      = ["FR", "BE", "CH", "LU"]
}

module "service_accounts" {
  source = "./modules/service-accounts"

  group_ids_by_name = module.groups.group_ids_by_name
  doppler_project   = "infrastructure"
  doppler_config    = "prd"
  rotation_trigger  = var.password_rotation_trigger
}

# -----------------------------------------------------------------------------
# Users avec rotation de mots de passe
# -----------------------------------------------------------------------------
module "users" {
  source = "./modules/users"
  count  = length(var.authentik_users) > 0 ? 1 : 0

  users             = var.authentik_users
  group_ids_by_name = module.groups.group_ids_by_name
  rotation_trigger  = var.password_rotation_trigger
  force_rotation    = var.force_password_rotation
}

# -----------------------------------------------------------------------------
# Doppler Secrets Management
# Stocke automatiquement les tokens et secrets dans Doppler
# -----------------------------------------------------------------------------

# Token Terraform CI/CD (service account)
resource "doppler_secret" "terraform_ci_token" {
  project = "infrastructure"
  config  = "prd"
  name    = "AUTHENTIK_TOKEN_TERRAFORM_CI"
  value   = authentik_token.terraform_ci.key
}

# Token principal Authentik pour les autres services
resource "doppler_secret" "authentik_token" {
  project = "infrastructure"
  config  = "prd"
  name    = "AUTHENTIK_TOKEN"
  value   = authentik_token.terraform_ci.key
}

# Rotation trigger dans Doppler pour traçabilité
resource "doppler_secret" "rotation_trigger" {
  project = "infrastructure"
  config  = "prd"
  name    = "AUTHENTIK_PASSWORD_ROTATION_TRIGGER"
  value   = var.password_rotation_trigger
}

# replace_triggered_by exige une référence à une ressource ; null_resource sert de trigger.
resource "null_resource" "password_rotation_trigger" {
  triggers = {
    trigger = var.password_rotation_trigger
  }
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

  lifecycle {
    replace_triggered_by = [null_resource.password_rotation_trigger]
  }
}

# -----------------------------------------------------------------------------
# Apps — Proxy (Omni, LiteLLM, OpenClaw, Odoo), OIDC, Cloudflare Access, Outpost
# -----------------------------------------------------------------------------
module "apps" {
  source = "./modules/apps"

  default_authorization_flow_id   = data.authentik_flow.default_authorization_flow.id
  default_invalidation_flow_id    = data.authentik_flow.default_invalidation.id
  default_certificate_key_pair_id = data.authentik_certificate_key_pair.default.id
  authentik_url                   = local.authentik_url
  domain                          = var.domain
  cloudflare_access_team          = var.cloudflare_access_team
  default_oidc_scope_mapping_ids  = module.scope_mappings.full_scope_mapping_list
}
