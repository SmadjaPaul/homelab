# Password Recovery Flow - Allows users to reset their password via email
# Based on Authentik default recovery flow blueprint
# Docs: https://docs.goauthentik.io/docs/flow/stages/recovery/

# =============================================================================
# Email Stage - Sends password reset emails
# =============================================================================
# SMTP configuration is read from OCI Vault secrets (see smtp-secrets.tf).
# If OCI secrets are available, use them directly; otherwise fall back to
# global settings (configured via environment variables in docker-compose.yml).
#
# To use OCI Vault secrets:
#   1. Set oci_compartment_id variable (from terraform/oracle-cloud outputs)
#   2. Ensure OCI provider credentials are configured
#   3. Secrets must exist in OCI Vault (created via terraform/oracle-cloud)
#
# Fallback: If oci_compartment_id is empty, use_global_settings=true (requires
# AUTHENTIK_EMAIL__* environment variables in docker-compose.yml).

resource "authentik_stage_email" "recovery_email" {
  name                = "default-recovery-email"
  use_global_settings = var.oci_compartment_id == "" || local.smtp_host == ""

  # Configure SMTP directly if OCI secrets are available
  host         = var.oci_compartment_id != "" && local.smtp_host != "" ? local.smtp_host : null
  port         = var.oci_compartment_id != "" && local.smtp_host != "" ? tonumber(local.smtp_port) : null
  username     = var.oci_compartment_id != "" && local.smtp_host != "" ? local.smtp_username : null
  password     = var.oci_compartment_id != "" && local.smtp_host != "" ? local.smtp_password : null
  use_tls      = var.oci_compartment_id != "" && local.smtp_host != "" ? true : null
  from_address = var.oci_compartment_id != "" && local.smtp_host != "" ? local.smtp_from : null

  token_expiry             = 30 # minutes
  subject                  = "Reset your password"
  template                 = "email/password_reset.html"
  activate_user_on_success = true
  timeout                  = 10
}

# =============================================================================
# Prompt Fields - Individual password fields
# =============================================================================

resource "authentik_stage_prompt_field" "recovery_password" {
  name        = "default-recovery-field-password"
  field_key   = "password"
  label       = "Password"
  type        = "password"
  required    = true
  placeholder = "Password"
  order       = 0
}

resource "authentik_stage_prompt_field" "recovery_password_repeat" {
  name        = "default-recovery-field-password-repeat"
  field_key   = "password_repeat"
  label       = "Password (repeat)"
  type        = "password"
  required    = true
  placeholder = "Password (repeat)"
  order       = 1
}

# =============================================================================
# Prompt Stage - Combines password fields
# =============================================================================

resource "authentik_stage_prompt" "recovery_prompt_password" {
  name = "Change your password"
  fields = [
    authentik_stage_prompt_field.recovery_password.id,
    authentik_stage_prompt_field.recovery_password_repeat.id,
  ]
}

# =============================================================================
# Identification Stage - User identifies by email or username
# =============================================================================

resource "authentik_stage_identification" "recovery_identification" {
  name        = "default-recovery-identification"
  user_fields = ["email", "username"]
}

# =============================================================================
# User Write Stage - Updates the user's password
# =============================================================================

resource "authentik_stage_user_write" "recovery_user_write" {
  name               = "default-recovery-user-write"
  user_creation_mode = "never_create"
}

# =============================================================================
# User Login Stage - Automatically logs in the user after password reset
# =============================================================================

resource "authentik_stage_user_login" "recovery_user_login" {
  name = "default-recovery-user-login"
}

# =============================================================================
# Expression Policy - Skip flow if user is already restored
# =============================================================================

resource "authentik_policy_expression" "recovery_skip_if_restored" {
  name       = "default-recovery-skip-if-restored"
  expression = "return bool(request.context.get('is_restored', True))"
}

# =============================================================================
# Recovery Flow
# =============================================================================

resource "authentik_flow" "recovery" {
  name           = "Default recovery flow"
  title          = "Reset your password"
  slug           = "default-recovery-flow"
  designation    = "recovery"
  authentication = "require_unauthenticated"
}

# =============================================================================
# Flow Stage Bindings - Connect stages to flow
# =============================================================================

resource "authentik_flow_stage_binding" "recovery_identification" {
  target                  = authentik_flow.recovery.id
  stage                   = authentik_stage_identification.recovery_identification.id
  order                   = 10
  evaluate_on_plan        = true
  re_evaluate_policies    = true
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_email" {
  target                  = authentik_flow.recovery.id
  stage                   = authentik_stage_email.recovery_email.id
  order                   = 20
  evaluate_on_plan        = true
  re_evaluate_policies    = true
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_prompt_password" {
  target                  = authentik_flow.recovery.id
  stage                   = authentik_stage_prompt.recovery_prompt_password.id
  order                   = 30
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_user_write" {
  target                  = authentik_flow.recovery.id
  stage                   = authentik_stage_user_write.recovery_user_write.id
  order                   = 40
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_user_login" {
  target                  = authentik_flow.recovery.id
  stage                   = authentik_stage_user_login.recovery_user_login.id
  order                   = 100
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

# =============================================================================
# Policy Bindings - Apply skip policy to identification and email stages
# =============================================================================

resource "authentik_policy_binding" "recovery_skip_identification" {
  target  = authentik_flow_stage_binding.recovery_identification.id
  policy  = authentik_policy_expression.recovery_skip_if_restored.id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}

# Note: The blueprint shows the email stage binding should NOT have the skip policy
# (state: absent), so we don't bind it here
