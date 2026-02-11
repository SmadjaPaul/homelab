# =============================================================================
# Data sources — resources existants Authentik (créés à l'install)
# =============================================================================
# Centralisé ici pour être passé aux modules.
# Docs: https://registry.terraform.io/providers/goauthentik/authentik/latest/docs

data "authentik_flow" "default_authorization_flow" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default_invalidation" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_flow" "default_authentication" {
  slug = "default-authentication-flow"
}

data "authentik_certificate_key_pair" "default" {
  name = "authentik Self-signed Certificate"
}
