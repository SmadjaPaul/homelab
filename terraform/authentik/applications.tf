# =============================================================================
# Audiobookshelf Integration (OAuth2/OIDC)
# =============================================================================

resource "authentik_provider_oauth2" "audiobookshelf" {
  name                = "Audiobookshelf"
  client_id           = "audiobookshelf"
  client_secret       = data.doppler_secrets.this.map.AUDIOBOOKSHELF_OIDC_CLIENT_SECRET
  authorization_flow  = data.authentik_flow.default_authorization_flow.id
  authentication_flow = data.authentik_flow.default_authentication_flow.id

  redirect_uris = [
    "https://audiobooks.smadja.dev/auth/openid/callback"
  ]
  
  property_mappings = [
    data.authentik_scope.openid.id,
    data.authentik_scope.profile.id,
    data.authentik_scope.email.id,
  ]
}

resource "authentik_application" "audiobookshelf" {
  name              = "Audiobookshelf"
  slug              = "audiobookshelf"
  protocol_provider = authentik_provider_oauth2.audiobookshelf.id
  group             = "Media"
  meta_icon         = "https://raw.githubusercontent.com/advplyr/audiobookshelf/master/public/favicon.ico"
}
