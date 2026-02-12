# =============================================================================
# Data sources — resources existants Authentik (créés à l'install)
# =============================================================================
# Centralisé ici pour être passé aux modules. Les slugs/noms sont configurables
# (var.authentik_flow_slug_*) si ton instance utilise d'autres valeurs.
# Docs: https://registry.terraform.io/providers/goauthentik/authentik/latest/docs

data "authentik_flow" "default_authorization_flow" {
  slug = var.authentik_flow_slug_authorization
}

data "authentik_flow" "default_invalidation" {
  slug = var.authentik_flow_slug_invalidation
}

data "authentik_flow" "default_authentication" {
  slug = var.authentik_flow_slug_authentication
}

data "authentik_certificate_key_pair" "default" {
  name = var.authentik_certificate_key_pair_name
}

# Default OAuth2 scope mappings so IdPs (e.g. Cloudflare Access) get user info from UserInfo endpoint
data "authentik_property_mapping_provider_scope" "openid" {
  scope_name = "openid"
}

data "authentik_property_mapping_provider_scope" "email" {
  scope_name = "email"
}

data "authentik_property_mapping_provider_scope" "profile" {
  scope_name = "profile"
}

locals {
  default_oidc_scope_mapping_ids = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.profile.id
  ]
}
