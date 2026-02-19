# =============================================================================
# Service Accounts Outputs
# =============================================================================

output "service_account_ids" {
  description = "Map des noms de service account vers leur ID"
  value = {
    for name, user in authentik_user.service_account : name => user.id
  }
}

output "service_account_tokens" {
  description = "Map des noms de service account vers leur token ID (sensitive)"
  value = {
    for name, token in authentik_token.service_token : name => token.id
  }
  sensitive = true
}

output "doppler_secrets_created" {
  description = "Liste des secrets Doppler créés"
  value = [
    for secret in doppler_secret.service_account_tokens : secret.name
  ]
}
