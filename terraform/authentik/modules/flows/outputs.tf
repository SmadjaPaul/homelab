output "recovery_flow_uuid" {
  value = authentik_flow.recovery.uuid
}

output "recovery_flow_slug" {
  value = authentik_flow.recovery.slug
}

output "identification_stage_id" {
  value = authentik_stage_identification.default_auth_with_recovery.id
}
