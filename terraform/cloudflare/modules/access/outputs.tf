output "auth0_idp_id" {
  description = "Auth0 IdP ID when enabled"
  value       = length(cloudflare_zero_trust_access_identity_provider.auth0) > 0 ? cloudflare_zero_trust_access_identity_provider.auth0[0].id : null
}

output "application_ids" {
  value = { for k, v in cloudflare_zero_trust_access_application.internal_services : k => v.id }
}
