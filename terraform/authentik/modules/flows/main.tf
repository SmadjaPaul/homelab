# =============================================================================
# Flows — Recovery, login link, security policies (password, reputation)
# =============================================================================

# ----- Recovery: email stage -----
resource "authentik_stage_email" "recovery_email" {
  name                = "default-recovery-email"
  use_global_settings = var.oci_compartment_id == "" || var.smtp_host == ""

  host         = var.oci_compartment_id != "" && var.smtp_host != "" ? var.smtp_host : null
  port         = var.oci_compartment_id != "" && var.smtp_host != "" ? tonumber(var.smtp_port) : null
  username     = var.oci_compartment_id != "" && var.smtp_host != "" ? var.smtp_username : null
  password     = var.oci_compartment_id != "" && var.smtp_host != "" ? var.smtp_password : null
  use_tls      = var.oci_compartment_id != "" && var.smtp_host != "" ? true : null
  from_address = var.oci_compartment_id != "" && var.smtp_host != "" ? var.smtp_from : null

  token_expiry             = 30
  subject                  = "Reset your password"
  template                 = "email/password_reset.html"
  activate_user_on_success = true
  timeout                  = 10
}

# ----- Recovery: prompt fields + stage -----
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

resource "authentik_stage_prompt" "recovery_prompt_password" {
  name   = "Change your password"
  fields = [authentik_stage_prompt_field.recovery_password.id, authentik_stage_prompt_field.recovery_password_repeat.id]
}

# ----- Recovery: identification, user write, user login -----
resource "authentik_stage_identification" "recovery_identification" {
  name        = "default-recovery-identification"
  user_fields = ["email", "username"]
}

resource "authentik_stage_user_write" "recovery_user_write" {
  name               = "default-recovery-user-write"
  user_creation_mode = "never_create"
}

resource "authentik_stage_user_login" "recovery_user_login" {
  name = "default-recovery-user-login"
}

# ----- Recovery: skip-if-restored policy -----
resource "authentik_policy_expression" "recovery_skip_if_restored" {
  name       = "default-recovery-skip-if-restored"
  expression = "return bool(request.context.get('is_restored', True))"
}

# ----- Recovery flow -----
resource "authentik_flow" "recovery" {
  name           = "Default recovery flow"
  title          = "Reset your password"
  slug           = "default-recovery-flow"
  designation    = "recovery"
  authentication = "require_unauthenticated"
}

# ----- Recovery: flow stage bindings -----
resource "authentik_flow_stage_binding" "recovery_identification" {
  depends_on              = [authentik_flow.recovery]
  target                  = authentik_flow.recovery.uuid
  stage                   = authentik_stage_identification.recovery_identification.id
  order                   = 10
  evaluate_on_plan        = true
  re_evaluate_policies    = true
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_email" {
  depends_on              = [authentik_flow.recovery]
  target                  = authentik_flow.recovery.uuid
  stage                   = authentik_stage_email.recovery_email.id
  order                   = 20
  evaluate_on_plan        = true
  re_evaluate_policies    = true
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_prompt_password" {
  depends_on              = [authentik_flow.recovery]
  target                  = authentik_flow.recovery.uuid
  stage                   = authentik_stage_prompt.recovery_prompt_password.id
  order                   = 30
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_user_write" {
  depends_on              = [authentik_flow.recovery]
  target                  = authentik_flow.recovery.uuid
  stage                   = authentik_stage_user_write.recovery_user_write.id
  order                   = 40
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_user_login" {
  depends_on              = [authentik_flow.recovery]
  target                  = authentik_flow.recovery.uuid
  stage                   = authentik_stage_user_login.recovery_user_login.id
  order                   = 100
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_policy_binding" "recovery_skip_identification" {
  target  = authentik_flow_stage_binding.recovery_identification.id
  policy  = authentik_policy_expression.recovery_skip_if_restored.id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}

# ----- Login flow: identification stage with recovery + auto-link script -----
resource "authentik_stage_identification" "default_auth_with_recovery" {
  depends_on    = [authentik_flow.recovery]
  name          = "default-authentication-identification-with-recovery"
  user_fields   = ["email", "username"]
  recovery_flow = authentik_flow.recovery.uuid
}

resource "null_resource" "link_recovery_flow" {
  triggers = {
    stage_id = authentik_stage_identification.default_auth_with_recovery.id
  }
  provisioner "local-exec" {
    command     = "bash ${var.link_recovery_script_path}"
    working_dir = path.module
    environment = {
      AUTHENTIK_URL   = var.authentik_url
      AUTHENTIK_TOKEN = var.authentik_token
    }
  }
}

# ----- Security: password policy + bind to recovery prompt -----
resource "authentik_policy_password" "strong" {
  name                    = "strong-password"
  length_min              = 12
  error_message           = "Le mot de passe doit contenir au moins 12 caractères, une majuscule, une minuscule, un chiffre et un symbole, et ne pas figurer dans des fuites connues."
  amount_uppercase        = 1
  amount_lowercase        = 1
  amount_digits           = 1
  amount_symbols          = 1
  symbol_charset          = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
  check_static_rules      = true
  check_have_i_been_pwned = true
  hibp_allowed_count      = 0
  check_zxcvbn            = true
  zxcvbn_score_threshold  = 3
  execution_logging       = false
}

resource "authentik_policy_binding" "recovery_password_policy" {
  target  = authentik_flow_stage_binding.recovery_prompt_password.id
  policy  = authentik_policy_password.strong.id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}

# ----- Security: reputation (brute-force) + bind to default auth flow -----
resource "authentik_policy_reputation" "login" {
  name              = "login-reputation"
  check_ip          = true
  check_username    = true
  threshold         = -5
  execution_logging = true
}

resource "authentik_policy_binding" "login_reputation" {
  target  = var.default_authentication_flow_id
  policy  = authentik_policy_reputation.login.id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}
