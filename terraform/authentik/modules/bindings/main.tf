# =============================================================================
# Bindings — Policy bindings (admin group) for Omni, LiteLLM, OpenClaw, OpenClaw OIDC
# =============================================================================

resource "authentik_policy_binding" "omni_admin_policy" {
  target  = var.omni_application_uuid
  policy  = var.admin_only_policy_id
  group   = var.admin_group_id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}

resource "authentik_policy_binding" "litellm_admin_policy" {
  target  = var.litellm_application_uuid
  policy  = var.admin_only_policy_id
  group   = var.admin_group_id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}

resource "authentik_policy_binding" "openclaw_admin_policy" {
  target  = var.openclaw_application_uuid
  policy  = var.admin_only_policy_id
  group   = var.admin_group_id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}

resource "authentik_policy_binding" "openclaw_oidc_admin_policy" {
  target  = var.openclaw_oidc_application_uuid
  policy  = var.admin_only_policy_id
  group   = var.admin_group_id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}
