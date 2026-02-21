output "cloudflare_client_id" {
  value = module.applications.applications["cloudflare_access"].client_id
}

output "cloudflare_client_secret" {
  value     = data.auth0_client.cloudflare_access_data.client_secret
  sensitive = true
}

output "auth0_domain" {
  value     = local.auth0_domain
  sensitive = true
}

output "organization_id" {
  value = auth0_organization.homelab.id
}

output "roles_created" {
  value = module.roles.role_ids
}

output "users_created" {
  value = module.users.user_ids
}
