# =============================================================================
# Users — authentik_user + assignation aux groupes
# =============================================================================
# Chaque utilisateur est créé avec les groupes demandés (group_names → IDs).
# Les groupes sont gérés manuellement via UI - Terraform ignore les changements.
# Rotation de mots de passe supportée via rotation_trigger.
# Référence: https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/user
# replace_triggered_by exige une référence à une ressource (pas une variable), d'où null_resource.
# =============================================================================

resource "null_resource" "rotation_trigger" {
  triggers = {
    rotation = var.force_rotation ? var.rotation_trigger : "no-rotation"
  }
}

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
    if contains(keys(var.group_ids_by_name), name)
  ]

  attributes = jsonencode({
    last_rotation  = var.rotation_trigger
    force_rotation = var.force_rotation
  })

  # Ignore groups changes - manage manually in UI
  lifecycle {
    ignore_changes       = [groups]
    replace_triggered_by = [null_resource.rotation_trigger]
  }
}
