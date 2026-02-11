output "user_ids" {
  description = "Map username → user UUID"
  value       = { for k, u in authentik_user.users : k => u.uuid }
}

output "user_ids_by_username" {
  description = "Map username → user id (numeric)"
  value       = { for k, u in authentik_user.users : k => u.id }
}
