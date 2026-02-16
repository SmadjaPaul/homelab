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

output "policy_ids_by_name" {
  description = "Policy IDs by logical name"
  value = {
    admin_only              = authentik_policy_expression.admin_only.id
    family_validated_only   = authentik_policy_expression.family_validated_only.id
    admin_and_validated     = authentik_policy_expression.admin_and_validated.id
    block_public_enrollment = authentik_policy_expression.block_public_enrollment.id
    professionnelle_only    = authentik_policy_expression.professionnelle_only.id
  }
}
