# =============================================================================
# Users — authentik_user + assignation aux groupes
# =============================================================================
# Chaque utilisateur est créé avec les groupes demandés (group_names → IDs).
# Les groupes sont gérés manuellement via UI - Terraform ignore les changements.
# Référence: https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/user
# =============================================================================

resource "authentik_user" "users" {
  for_each = { for i, u in var.users : u.username => u }

  username  = each.value.username
  name      = each.value.name
  email     = each.value.email
  is_active = each.value.is_active
  path      = each.value.path != "" ? each.value.path : null
  password  = each.value.password != "" ? each.value.password : null

  groups = [
    for name in each.value.group_names :
    var.group_ids_by_name[name]
  ]

  # Ignore groups changes - manage manually in UI
  lifecycle {
    ignore_changes = [groups]
  }
}
