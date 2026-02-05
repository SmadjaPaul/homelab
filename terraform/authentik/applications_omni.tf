# Omni (Talos management) — Forward Auth Provider + Application (Traefik)
# Flow: Traefik → Forward Auth (outpost) → if OK, proxy to Omni. Outpost validates only; Traefik proxies.
# Ref: https://docs.goauthentik.io/docs/providers/proxy/server_traefik

variable "domain" {
  description = "Public domain for external_host (e.g. omni.smadja.dev)"
  type        = string
  default     = "smadja.dev"
}

# Note: data.authentik_flow.default_invalidation est défini dans data.tf

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

# Group binding: users in group "admin" can access Omni (visible in "Mes applications")
resource "authentik_policy_binding" "omni_admin" {
  target = authentik_application.omni.uuid
  group  = authentik_group.admin.id
  order  = 0
}

# Embedded outpost: assign omni-proxy so Forward Auth works for omni.smadja.dev.
# First time only: import the existing outpost (Admin → Outposts → copy UUID from URL or API):
#   terraform import authentik_outpost.embedded <OUTPOST_UUID>
resource "authentik_outpost" "embedded" {
  name               = "authentik Embedded Outpost"
  type               = "proxy"
  protocol_providers = [authentik_provider_proxy.omni.id]
  # service_connection: leave unset so import keeps existing (embedded) connection
}
