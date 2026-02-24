# =============================================================================
# System Data Lookups
# =============================================================================

data "authentik_flow" "default_authorization_flow" {
  slug = "default-provider-authorization-explicit-confirmation"
}

data "authentik_flow" "default_authentication_flow" {
  slug = "default-authentication-flow"
}

data "authentik_flow" "default_invalidation_flow" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_property_mapping_provider_scope" "openid" {
  name = "openid"
}

data "authentik_property_mapping_provider_scope" "profile" {
  name = "profile"
}

data "authentik_property_mapping_provider_scope" "email" {
  name = "email"
}
