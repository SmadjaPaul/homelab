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

# Outpost for Forward Auth (Traefik) — validates omni + litellm (and any other proxy app)
# Without this, "Aucune intégration active" and Forward Auth returns 500.
# Token: Authentik UI → Avant-postes → [Homelab Forward Auth] → Token (set AUTHENTIK_OUTPOST_TOKEN in .env).
resource "authentik_outpost" "proxy_forward_auth" {
  name               = "Homelab Forward Auth"
  type               = "proxy"
  protocol_providers = [authentik_provider_proxy.omni.id, authentik_provider_proxy.litellm.id, authentik_provider_proxy.openclaw.id]
}

output "omni_outpost_note" {
  description = "After apply: set AUTHENTIK_OUTPOST_TOKEN from Authentik UI (Avant-postes → Homelab Forward Auth → Token)"
  value       = "Outpost 'Homelab Forward Auth' created. Get its token in Authentik → Avant-postes → Homelab Forward Auth, then set AUTHENTIK_OUTPOST_TOKEN in docker/oci-mgmt/.env and restart authentik-outpost-proxy."
}
