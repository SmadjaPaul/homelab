# =============================================================================
# Service Accounts — Création et gestion des comptes de service
# =============================================================================

# Créer les comptes de service
resource "authentik_user" "service_account" {
  for_each = { for sa in var.service_accounts : sa.name => sa }

  username  = each.value.name
  name      = each.value.description != "" ? each.value.description : each.value.name
  type      = "service_account"
  path      = each.value.path
  is_active = true

  # Assigner aux groupes
  groups = [
    for name in each.value.group_names :
    var.group_ids_by_name[name]
    if contains(keys(var.group_ids_by_name), name)
  ]

  attributes = jsonencode({
    service_account = true
    managed_by      = "terraform"
    created_at      = timestamp()
  })
}

# replace_triggered_by exige une référence à une ressource ; null_resource sert de trigger.
resource "null_resource" "rotation_trigger" {
  triggers = {
    rotation = var.rotation_trigger
  }
}

# Générer des tokens pour chaque service account
resource "authentik_token" "service_token" {
  for_each = { for sa in var.service_accounts : sa.name => sa }

  identifier   = "${each.value.name}-token"
  user         = authentik_user.service_account[each.key].id
  description  = "API token for ${each.value.name}"
  intent       = "api"
  expiring     = each.value.token_expires != ""
  expires      = each.value.token_expires != "" ? each.value.token_expires : null
  retrieve_key = true

  lifecycle {
    replace_triggered_by = [null_resource.rotation_trigger]
  }
}

# Stocker les tokens dans Doppler automatiquement
resource "doppler_secret" "service_account_tokens" {
  for_each = { for sa in var.service_accounts : sa.name => sa }

  project = var.doppler_project
  config  = var.doppler_config
  name    = "AUTHENTIK_TOKEN_${upper(replace(each.value.name, "-", "_"))}"
  value   = authentik_token.service_token[each.key].key

  lifecycle {
    replace_triggered_by = [authentik_token.service_token[each.key]]
  }
}
