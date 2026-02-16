output "user_ids" {
  description = "Map username → user id (pk)"
  value       = { for k, u in authentik_user.users : k => u.id }
}
