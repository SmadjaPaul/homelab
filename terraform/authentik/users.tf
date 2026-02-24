# =============================================================================
# Authentik Users
# =============================================================================

resource "authentik_user" "all" {
  for_each = local.users
  username = each.value.username
  name     = each.value.name
  email    = each.value.email
  groups   = [for g in each.value.groups : authentik_group.all[lower(replace(g, " ", "_"))].id]
}
