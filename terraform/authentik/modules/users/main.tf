# =============================================================================
# Users — authentik_user + assignation aux groupes
# =============================================================================
# Chaque utilisateur est créé avec les groupes demandés (group_names → IDs).
# Référence: https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/user
# =============================================================================

resource "authentik_user" "users" {
  for_each = { for i, u in var.users : u.username => u }

  username  = each.value.username
  name      = each.value.name
  email     = each.value.email
  is_active = each.value.is_active
  path      = each.value.path != "" ? each.value.path : null

  # Résolution des IDs de groupe à partir des noms
  groups = [
    for name in each.value.group_names :
    var.group_ids_by_name[name]
  ]
}
