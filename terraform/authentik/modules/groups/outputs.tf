output "admin_group_id" {
  description = "ID du groupe admin"
  value       = authentik_group.admin.id
}

output "family_validated_group_id" {
  description = "ID du groupe family-validated"
  value       = authentik_group.family_validated.id
}

# Map group name -> id for use in Users module or policies
output "group_ids_by_name" {
  description = "Map des noms de groupe vers leur ID (pour bindings ou users)"
  value = {
    admin            = authentik_group.admin.id
    family-validated = authentik_group.family_validated.id
  }
}

output "rbac_matrix_note" {
  description = "Résumé RBAC : quel groupe a accès à quelles apps"
  value       = local.rbac_matrix_note
}

locals {
  rbac_matrix_note = <<-EOT
    RBAC (see docs/RBAC.md):
    - admin             → Omni, LiteLLM, OpenClaw, OpenClaw OIDC, Cloudflare Access
    - family-validated → (future) family apps; used in admin_and_validated policy
  EOT
}
