# =============================================================================
# Authentik — Root module (orchestration)
# =============================================================================
# Order: Groups → Policies → Flows → Apps → Bindings [→ Users]
# Data sources (flows, cert) are in data.tf; SMTP locals in smtp-secrets.tf.
# RBAC: voir docs/RBAC.md
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

module "flows" {
  source = "./modules/flows"

  oci_compartment_id             = var.oci_compartment_id
  smtp_host                      = local.smtp_host
  smtp_port                      = local.smtp_port
  smtp_username                  = local.smtp_username
  smtp_password                  = local.smtp_password
  smtp_from                      = local.smtp_from
  default_authentication_flow_id = data.authentik_flow.default_authentication.id
  authentik_url                  = var.authentik_url
  authentik_token                = var.authentik_token
  link_recovery_script_path      = abspath("${path.module}/../../scripts/link-recovery-flow.sh")
}

module "apps" {
  source = "./modules/apps"

  domain                          = var.domain
  default_authorization_flow_id   = data.authentik_flow.default_authorization_flow.id
  default_invalidation_flow_id    = data.authentik_flow.default_invalidation.id
  default_certificate_key_pair_id = data.authentik_certificate_key_pair.default.id
  authentik_url                   = var.authentik_url
  cloudflare_access_team          = var.cloudflare_access_team
  default_oidc_scope_mapping_ids  = local.default_oidc_scope_mapping_ids
}

module "bindings" {
  source = "./modules/bindings"

  admin_only_policy_id           = module.policies.admin_only_id
  omni_application_uuid          = module.apps.omni_application_uuid
  litellm_application_uuid       = module.apps.litellm_application_uuid
  openclaw_application_uuid      = module.apps.openclaw_application_uuid
  openclaw_oidc_application_uuid = module.apps.openclaw_oidc_application_uuid
}
