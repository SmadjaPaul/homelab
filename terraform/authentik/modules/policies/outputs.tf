output "admin_only_id" {
  value = authentik_policy_expression.admin_only.id
}

output "family_validated_only_id" {
  value = authentik_policy_expression.family_validated_only.id
}

output "admin_and_validated_id" {
  value = authentik_policy_expression.admin_and_validated.id
}

output "block_public_enrollment_id" {
  value = authentik_policy_expression.block_public_enrollment.id
}

output "professionnelle_only_id" {
  value = authentik_policy_expression.professionnelle_only.id
}
