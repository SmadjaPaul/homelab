# LiteLLM (proxy IA) — Forward Auth Provider + Application (Traefik)
# Flow: Traefik → Forward Auth (outpost) → if OK, proxy to LiteLLM.
# Même schéma qu'Omni : outpost valide la session Authentik, Traefik proxy vers litellm:4000.
# default_invalidation / default_authorization_flow : voir applications_omni.tf et data.tf

resource "authentik_provider_proxy" "litellm" {
  name               = "litellm-proxy"
  mode               = "forward_single"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id
  external_host      = "https://llm.${var.domain}"
}

resource "authentik_application" "litellm" {
  name               = "LiteLLM"
  slug               = "litellm"
  protocol_provider  = authentik_provider_proxy.litellm.id
  policy_engine_mode = "any"
}

# Accès réservé aux admins (même politique qu'Omni)
resource "authentik_policy_binding" "litellm_admin_policy" {
  target  = authentik_application.litellm.uuid
  policy  = authentik_policy_expression.admin_only.id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}

output "litellm_forward_auth_note" {
  description = "LiteLLM is behind Authentik Forward Auth; bind admin group in UI if needed"
  value       = "Application 'LiteLLM' (llm.smadja.dev) uses same outpost as Omni. Bind group 'admin' in Applications → LiteLLM → Policy/Group Bindings if needed."
}
