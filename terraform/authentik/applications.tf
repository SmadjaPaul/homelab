# =============================================================================
# Audiobookshelf Integration (OAuth2/OIDC)
# =============================================================================

resource "authentik_provider_oauth2" "audiobookshelf" {
  name                = "Audiobookshelf"
  client_id           = "audiobookshelf"
  client_secret       = data.doppler_secrets.this.map.AUDIOBOOKSHELF_OIDC_CLIENT_SECRET
  authorization_flow  = data.authentik_flow.default_authorization_flow.id
  authentication_flow = data.authentik_flow.default_authentication_flow.id
  invalidation_flow   = data.authentik_flow.default_invalidation_flow.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://audiobooks.smadja.dev/auth/openid/callback"
    },
    {
      matching_mode = "strict"
      url           = "https://audiobooks.smadja.dev/auth/openid/mobile-redirect"
    }
  ]

  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    data.authentik_property_mapping_provider_scope.email.id,
  ]
}

resource "authentik_application" "audiobookshelf" {
  name              = "Audiobookshelf"
  slug              = "audiobookshelf"
  protocol_provider = authentik_provider_oauth2.audiobookshelf.id
  group             = "Media"
  meta_icon         = "https://raw.githubusercontent.com/advplyr/audiobookshelf/master/public/favicon.ico"
}
