# =============================================================================
# Outputs — Re-export from modules
# =============================================================================

output "omni_outpost_note" {
  description = "After apply: set AUTHENTIK_OUTPOST_TOKEN from Authentik UI"
  value       = module.apps.omni_outpost_note
}

output "openclaw_oidc" {
  description = "OIDC settings for OpenClaw (AUTHENTICATION_METHOD=oidc)"
  value       = module.apps.openclaw_oidc
  sensitive   = true
}

output "cloudflare_access_oidc" {
  description = "OIDC credentials and URLs for Cloudflare Zero Trust IdP configuration"
  value       = module.apps.cloudflare_access_oidc
  sensitive   = true
}

output "recovery_flow_slug" {
  description = "Slug of the recovery flow"
  value       = module.flows.recovery_flow_slug
}

output "identification_stage_id" {
  description = "ID of the identification stage with recovery flow"
  value       = module.flows.identification_stage_id
}

output "recovery_linked_note" {
  description = "Recovery flow link instructions"
  value       = "Recovery flow linked automatically when AUTHENTIK_TOKEN is set at apply time. If skipped, run: ./scripts/link-recovery-flow.sh <URL> <TOKEN>"
}

output "enrollment_flow_disabled_note" {
  description = "Enrollment: policy block-public-enrollment is in Policies module; disable flow in UI if needed"
  value       = "Policy block-public-enrollment created. To disable self-registration: Flows → default-enrollment-flow → Settings → Uncheck 'Allow user to start this flow'."
}

output "rbac_matrix_note" {
  description = "Résumé RBAC (détail dans terraform/authentik/docs/RBAC.md)"
  value       = module.groups.rbac_matrix_note
}

output "managed_user_usernames" {
  description = "Usernames des utilisateurs gérés par Terraform (si authentik_users non vide)"
  value       = length(var.authentik_users) > 0 ? keys(module.users[0].user_ids) : []
}
