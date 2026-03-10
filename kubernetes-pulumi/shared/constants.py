"""
Shared constants for the Homelab infrastructure.
Centralizes values that are referenced across multiple files to prevent
hidden coupling and silent breakage.
"""

# Authentik
AUTHENTIK_NAMESPACE = "authentik"
AUTHENTIK_OUTPOST_NAME = "authentik-embedded-outpost"
AUTHENTIK_OUTPOST_SVC = (
    f"http://ak-outpost-{AUTHENTIK_OUTPOST_NAME}"
    f".{AUTHENTIK_NAMESPACE}.svc.cluster.local:9000"
)

# Authentik Default Flows (by slug — stable across reinstalls)
FLOW_AUTHORIZATION_SLUG = "default-provider-authorization-implicit-consent"
FLOW_INVALIDATION_SLUG = "default-invalidation-flow"
