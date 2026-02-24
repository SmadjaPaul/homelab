# =============================================================================
# Authentik Groups
# =============================================================================

resource "authentik_group" "admins" {
  name = "Admins"
}

resource "authentik_group" "media" {
  name = "Media Users"
}

# =============================================================================
# Audiobookshelf Integration (OIDC)
# =============================================================================

resource "authentik_provider_oauth2" "audiobookshelf" {
  name                  = "Audiobookshelf"
  client_id             = "audiobookshelf"
  client_secret         = data.doppler_secrets.this.map.AUDIOBOOKSHELF_OIDC_CLIENT_SECRET
  authorization_flow    = data.authentik_flow.default_authorization_flow.id
  authentication_flow   = data.authentik_flow.default_authentication_flow.id
  
  redirect_uris = [
    "https://audiobooks.smadja.dev/auth/openid/callback"
  ]
}

resource "authentik_application" "audiobookshelf" {
  name              = "Audiobookshelf"
  slug              = "audiobookshelf"
  protocol_provider = authentik_provider_oauth2.audiobookshelf.id
  group             = "Media"
  meta_icon         = "https://raw.githubusercontent.com/advplyr/audiobookshelf/master/public/favicon.ico"
}

# Data lookups for default flows
data "authentik_flow" "default_authorization_flow" {
  slug = "default-provider-authorization-explicit-confirmation"
}

data "authentik_flow" "default_authentication_flow" {
  slug = "default-authentication-flow"
}
