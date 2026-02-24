# =============================================================================
# Authentik Groups
# =============================================================================

resource "authentik_group" "all" {
  for_each = local.groups
  name     = each.value.name
}
