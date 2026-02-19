# =============================================================================
# Security Policies Outputs
# =============================================================================

output "rate_limit_policy_ids" {
  description = "IDs des policies de rate limiting"
  value = var.enable_rate_limiting ? {
    reputation = authentik_policy_reputation.rate_limit_login[0].id
    expression = authentik_policy_expression.login_rate_limit[0].id
  } : {}
}

output "geo_restriction_policy_id" {
  description = "ID de la policy de geo-restriction"
  value       = var.enable_geo_restriction ? authentik_policy_expression.geo_restriction[0].id : null
}

output "suspicious_login_policy_id" {
  description = "ID de la policy de détection des connexions suspectes"
  value       = authentik_policy_expression.suspicious_login_detection.id
}

output "mfa_requirement_policy_id" {
  description = "ID de la policy requérant MFA pour les groupes sensibles"
  value       = authentik_policy_expression.require_mfa_for_sensitive.id
}
