# =============================================================================
# Bindings — Policy bindings: admin_only (Omni, LiteLLM, OpenClaw), professionnelle_only (Odoo)
# =============================================================================
# L'API Authentik n'accepte qu'un seul parmi group / policy / user par binding.
# On lie une policy par app (admin_only ou professionnelle_only).
# =============================================================================

resource "authentik_policy_binding" "omni_admin_policy" {
  target  = var.omni_application_uuid
  policy  = var.admin_only_policy_id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}

resource "authentik_policy_binding" "litellm_admin_policy" {
  target  = var.litellm_application_uuid
  policy  = var.admin_only_policy_id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}

resource "authentik_policy_binding" "openclaw_admin_policy" {
  target  = var.openclaw_application_uuid
  policy  = var.admin_only_policy_id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}

resource "authentik_policy_binding" "openclaw_oidc_admin_policy" {
  target  = var.openclaw_oidc_application_uuid
  policy  = var.admin_only_policy_id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}

# Odoo — accès réservé au groupe professionnelle
resource "authentik_policy_binding" "odoo_professionnelle_policy" {
  target  = var.odoo_application_uuid
  policy  = var.professionnelle_only_policy_id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}
