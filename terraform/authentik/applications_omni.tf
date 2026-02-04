# Omni (Talos management) — Forward Auth Provider + Application (Traefik)
# Flow: Traefik → Forward Auth (outpost) → if OK, proxy to Omni. Outpost validates only; Traefik proxies.
# Ref: https://docs.goauthentik.io/docs/providers/proxy/server_traefik

variable "domain" {
  description = "Public domain for external_host (e.g. omni.smadja.dev)"
  type        = string
  default     = "smadja.dev"
}

data "authentik_flow" "default_invalidation" {
  slug = "default-provider-invalidation-flow"
}

resource "authentik_provider_proxy" "omni" {
  name               = "omni-proxy"
  mode               = "forward_single" # Traefik does the proxying; outpost only validates
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id
  external_host      = "https://omni.${var.domain}"
  # internal_host not used in forward_single (Traefik proxies to omni:8080)
}

resource "authentik_application" "omni" {
  name               = "Omni"
  slug               = "omni"
  protocol_provider  = authentik_provider_proxy.omni.id
  policy_engine_mode = "any" # Allow if user matches any bound policy
}

# Assign group "admin" to Omni in Authentik UI:
# Applications → Omni → Policy / Group / User Bindings → Add group "admin"
# (Provider goauthentik/authentik may not expose policy_group in this version)
