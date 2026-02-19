# =============================================================================
# Scope Mappings Outputs
# =============================================================================

output "scope_mapping_ids" {
  description = "IDs de tous les scope mappings créés"
  value = {
    openid            = authentik_property_mapping_provider_scope.openid.id
    email             = authentik_property_mapping_provider_scope.email.id
    profile           = authentik_property_mapping_provider_scope.profile.id
    groups            = var.create_cloudflare_access_mappings ? authentik_property_mapping_provider_scope.groups[0].id : null
    cloudflare_access = var.create_cloudflare_access_mappings ? authentik_property_mapping_provider_scope.cloudflare_access[0].id : null
  }
}

output "default_scope_mapping_ids" {
  description = "IDs des scope mappings par défaut d'Authentik"
  value = {
    openid  = data.authentik_property_mapping_provider_scope.openid_default.id
    email   = data.authentik_property_mapping_provider_scope.email_default.id
    profile = data.authentik_property_mapping_provider_scope.profile_default.id
  }
}

# Liste complète pour les providers OIDC
output "full_scope_mapping_list" {
  description = "Liste complète des IDs pour utilisation dans les providers"
  value = compact([
    authentik_property_mapping_provider_scope.openid.id,
    authentik_property_mapping_provider_scope.email.id,
    authentik_property_mapping_provider_scope.profile.id,
    var.create_cloudflare_access_mappings ? authentik_property_mapping_provider_scope.groups[0].id : null,
  ])
}
