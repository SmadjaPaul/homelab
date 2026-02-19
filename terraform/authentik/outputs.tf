# =============================================================================
# Outputs — Authentik Infrastructure
# =============================================================================

output "group_ids" {
  description = "Group IDs by name"
  value       = module.groups.group_ids_by_name
}

output "policy_ids" {
  description = "Policy IDs by name"
  value       = module.policies.policy_ids_by_name
}

output "security_policy_ids" {
  description = "Security policy IDs"
  value       = module.security_policies.rate_limit_policy_ids
}

output "scope_mapping_ids" {
  description = "Scope mapping IDs for OIDC"
  value       = module.scope_mappings.scope_mapping_ids
}

output "service_account_ids" {
  description = "Service account IDs"
  value       = module.service_accounts.service_account_ids
}

output "managed_user_usernames" {
  description = "Usernames of users managed by Terraform"
  value       = length(var.authentik_users) > 0 ? [for u in var.authentik_users : u.username] : []
}

output "doppler_secrets_updated" {
  description = "Secrets Doppler automatiquement mis à jour"
  value = {
    terraform_ci_token = doppler_secret.terraform_ci_token.name
    rotation_trigger   = doppler_secret.rotation_trigger.name
    service_accounts   = module.service_accounts.doppler_secrets_created
  }
}

output "status_note" {
  description = "Configuration status"
  value       = <<EOF
✅ Authentik Terraform Configuration Complete!

Resources configured:
- Groups: ${length(module.groups.group_ids_by_name)} configured
- Policies: ${length(module.policies.policy_ids_by_name)} configured
- Security Policies: Rate limiting, Suspicious login detection, MFA requirements
- Scope Mappings: OIDC scopes for Cloudflare Access
- Service Accounts: ${length(module.service_accounts.service_account_ids)} created with auto-rotation
- Users: ${length(var.authentik_users)} managed
- Token: terraform-ci-token created for CI/CD

🔐 Doppler Secrets Updated:
- AUTHENTIK_TOKEN_TERRAFORM_CI (auto-generated)
- Service account tokens (auto-rotation supported)
- Rotation trigger tracking

🔑 Bootstrap Token Workflow:
1. AUTHENTIK_BOOTSTRAP_TOKEN used for initial authentication
2. Terraform creates permanent token: terraform-ci-token
3. Token automatically saved to Doppler
4. Future runs can use AUTHENTIK_TOKEN from Doppler

⚠️ Password Rotation:
   terraform apply -var="password_rotation_trigger=v2"

   Force rotation:
   terraform apply -var="force_password_rotation=true"

📚 Documentation: See docs/RBAC.md for full RBAC matrix
EOF
}
