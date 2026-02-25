# =============================================================================
# System Data Lookups
# =============================================================================

data "authentik_flow" "default_authorization_flow" {
  slug = "default-provider-authorization-explicit-consent"
}

data "authentik_flow" "default_authentication_flow" {
  slug = "default-authentication-flow"
}

data "authentik_flow" "default_invalidation_flow" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_property_mapping_provider_scope" "openid" {
  name = "authentik default OAuth Mapping: OpenID 'openid'"
}

data "authentik_property_mapping_provider_scope" "profile" {
  name = "authentik default OAuth Mapping: OpenID 'profile'"
}

data "authentik_property_mapping_provider_scope" "email" {
  name = "authentik default OAuth Mapping: OpenID 'email'"
}
