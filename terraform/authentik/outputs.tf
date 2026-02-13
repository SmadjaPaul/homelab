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
Authentik Terraform Configuration Summary:
- Groups: ${length(module.groups.group_ids_by_name)} configured
- Policies: ${length(module.policies.policy_ids_by_name)} configured
- Users: ${length(var.authentik_users)} managed

Note: Groups are managed manually in UI. Terraform ignores group changes.
To enable full automation, create a superuser token in Authentik UI:
1. Go to https://auth.smadja.dev/if/admin/
2. Administration → Tokens → Create
3. Check "Superuser" checkbox
4. Copy token and update AUTHENTIK_TOKEN
5. Re-enable flows/apps/bindings modules in main.tf
EOF
}
