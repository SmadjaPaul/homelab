# =============================================================================
# Audiobookshelf Proxy Auth (Forward Auth)
# =============================================================================

resource "authentik_provider_proxy" "audiobookshelf" {
  name                = "Audiobookshelf Proxy"
  external_host       = "https://audiobooks.smadja.dev"
  mode                = "forward_single"
  authorization_flow  = data.authentik_flow.default_authorization_flow.id
  authentication_flow = data.authentik_flow.default_authentication_flow.id
  invalidation_flow   = data.authentik_flow.default_invalidation_flow.id
}

resource "authentik_application" "audiobookshelf_proxy" {
  name              = "Audiobookshelf Proxy"
  slug              = "audiobookshelf-proxy"
  protocol_provider = authentik_provider_proxy.audiobookshelf.id
  group             = "Media"
  meta_icon         = "https://raw.githubusercontent.com/advplyr/audiobookshelf/master/public/favicon.ico"
}
