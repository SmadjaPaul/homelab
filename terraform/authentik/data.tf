# Data sources: reference existing Authentik resources (created at install)
# Docs: https://registry.terraform.io/providers/goauthentik/authentik/latest/docs

data "authentik_flow" "default_authorization_flow" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_certificate_key_pair" "default" {
  name = "authentik Self-signed Certificate"
}

data "authentik_flow" "default_invalidation" {
  slug = "default-provider-invalidation-flow"
}
