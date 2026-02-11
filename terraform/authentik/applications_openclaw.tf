# OpenClaw (personal AI gateway) — Forward Auth Provider + Application (Traefik)
# Flow: Traefik → Forward Auth (outpost) → if OK, proxy to OpenClaw gateway (port 18789).
# Same pattern as LiteLLM/Omni.

resource "authentik_provider_proxy" "openclaw" {
  name               = "openclaw-proxy"
  mode               = "forward_single"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id
  external_host      = "https://openclaw.${var.domain}"
}

resource "authentik_application" "openclaw" {
  name               = "OpenClaw"
  slug               = "openclaw"
  protocol_provider  = authentik_provider_proxy.openclaw.id
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "openclaw_admin_policy" {
  target  = authentik_application.openclaw.uuid
  policy  = authentik_policy_expression.admin_only.id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}

output "openclaw_forward_auth_note" {
  description = "OpenClaw is behind Authentik Forward Auth"
  value       = "Application 'OpenClaw' (openclaw.smadja.dev) uses same outpost as Omni/LiteLLM. Bind group 'admin' in Applications → OpenClaw if needed."
}
