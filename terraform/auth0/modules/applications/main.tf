# =============================================================================
# Applications Module
# =============================================================================
# Creates OIDC applications for Cloudflare Access and other services
# =============================================================================

variable "applications" {
  description = "Map of applications to create"
  type = map(object({
    app_type        = string
    description     = string
    callbacks       = list(string)
    allowed_logouts = list(string)
  }))
  default = {
    cloudflare_access = {
      app_type        = "regular_web"
      description     = "OIDC application for Cloudflare Access SSO"
      callbacks       = ["https://smadja.cloudflareaccess.com/cdn-cgi/access/callback"]
      allowed_logouts = ["https://smadja.dev"]
    }
    audiobookshelf = {
      app_type        = "regular_web"
      description     = "OIDC application for Audiobookshelf"
      callbacks       = ["https://audio.smadja.dev/auth/openid/callback"]
      allowed_logouts = ["https://audio.smadja.dev"]
    }
    vaultwarden = {
      app_type        = "regular_web"
      description     = "OIDC application for Vaultwarden"
      callbacks       = ["https://vault.smadja.dev/identity/connect/authorize/callback"] # Hypothetical if using OIDC proxy
      allowed_logouts = ["https://vault.smadja.dev"]
    }
  }
}

resource "auth0_client" "this" {
  for_each = var.applications

  name                = each.key
  app_type            = each.value.app_type
  description         = each.value.description
  callbacks           = each.value.callbacks
  allowed_logout_urls = each.value.allowed_logouts
  oidc_conformant     = true

  # Grant types needed for Cloudflare Access
  grant_types = ["authorization_code", "refresh_token", "client_credentials"]

  jwt_configuration {
    alg = "RS256"
  }
}

output "applications" {
  description = "Created applications"
  value       = auth0_client.this
}

output "application_clients" {
  description = "Map of application names to client credentials"
  value = {
    for k, v in auth0_client.this : k => {
      client_id = v.client_id
    }
  }
}
