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

output "managed_user_usernames" {
  description = "Usernames of users managed by Terraform"
  value       = length(var.authentik_users) > 0 ? [for u in var.authentik_users : u.username] : []
}

output "status_note" {
  description = "Configuration status"
  value       = <<EOF
✅ Authentik Terraform Configuration Complete!

Resources configured:
- Groups: ${length(module.groups.group_ids_by_name)} configured
- Policies: ${length(module.policies.policy_ids_by_name)} configured
- Users: ${length(var.authentik_users)} managed
- Token: terraform-ci-token created for CI/CD

🔑 Bootstrap Token Workflow:
1. AUTHENTIK_BOOTSTRAP_TOKEN used for initial authentication
2. Terraform creates permanent token: terraform-ci-token
3. Save the terraform_token output to Doppler as AUTHENTIK_TOKEN
4. Future runs can use AUTHENTIK_TOKEN (more secure)

⚠️ Important: Save the terraform_token output to Doppler:
   doppler secrets set AUTHENTIK_TOKEN "<token>" -p authentik -c prd

Note: Groups are managed manually in UI. Terraform ignores group changes.
EOF
}
