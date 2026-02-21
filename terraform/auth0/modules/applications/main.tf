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

  addons {
    samlp {
      audience  = "https://smadja.cloudflareaccess.com/cdn-cgi/access/callback"
      recipient = "https://smadja.cloudflareaccess.com/cdn-cgi/access/callback"
      mappings = {
        email    = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
        name     = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
        nickname = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nickname"
        roles    = "http://schemas.auth0.com/roles"
      }
      create_upn_claim                   = true
      passthrough_claims_with_no_mapping = true
      map_unknown_claims_as_is           = true
      map_identities                     = true
      name_identifier_format             = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
      name_identifier_probes             = ["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"]
    }
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
