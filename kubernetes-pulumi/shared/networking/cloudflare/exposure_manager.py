"""
Manages Cloudflare Tunnel Ingress rules for applications.
DNS records are handled by external-dns (K8s operator) via auto-discovery
from the Authentik Outpost Ingress.

TRAFFIC FLOW:
  User → Cloudflare DNS (external-dns) → Tunnel (this) → Authentik Outpost → App

RELATED FILES:
  - shared/apps/impl/cloudflared.py: Deploys the tunnel pod
  - shared/apps/common/authentik_registry.py: Creates the Authentik Outpost
  - apps.yaml: Source of truth for hostnames and exposure modes
  - k8s-apps/__main__.py: Orchestrates deployment phases
"""

import pulumi
import pulumi_cloudflare as cloudflare
from typing import List

from shared.constants import AUTHENTIK_OUTPOST_SVC
from shared.utils.schemas import AppModel, ExposureMode


class TunnelManager:
    """
    Manages Cloudflare Tunnel Ingress rules for applications.
    DNS is NOT managed here — external-dns auto-discovers records
    from the Authentik Outpost Ingress.
    """

    def __init__(
        self,
        account_id: str,
        tunnel_id: str,
        domain: str,
        provider: cloudflare.Provider,
        parent: pulumi.ComponentResource,
    ):
        self.account_id = account_id
        self.tunnel_id = tunnel_id
        self.domain = domain
        self.cf_provider = provider
        self.parent = parent

    def setup_tunnel(self, apps: List[AppModel]) -> List[pulumi.Resource]:
        """
        Creates Tunnel Ingress rules for all apps with a hostname.
        Protected apps are routed through the Authentik Outpost.
        Public apps are routed directly to their K8s service.
        """
        resources = []
        ingress_rules = []

        local_opts = pulumi.ResourceOptions(
            parent=self.parent, provider=self.cf_provider
        )

        # Sort apps for deterministic tunnel config ordering
        sorted_apps = sorted(apps, key=lambda x: x.name)

        for app in sorted_apps:
            pulumi.log.info(
                f"Checking tunnel routing for {app.name} (hostname: {app.hostname})"
            )
            if not app.hostname:
                continue

            # Route: protected → Authentik Outpost, public → direct service
            if app.mode == ExposureMode.PROTECTED:
                service_url = AUTHENTIK_OUTPOST_SVC
            else:
                svc_name = app.service_name or app.name
                service_url = (
                    f"http://{svc_name}.{app.namespace}.svc.cluster.local:{app.port}"
                )

            ingress_rules.append(
                {
                    "hostname": app.hostname,
                    "service": service_url,
                }
            )

        # Default catch-all rule (404)
        ingress_rules.append({"service": "http_status:404"})

        # Tunnel Configuration (Zero Trust Tunnel Cloudflared Config)
        tunnel_config = cloudflare.ZeroTrustTunnelCloudflaredConfig(
            "tunnel-config-applications",
            tunnel_id=self.tunnel_id,
            account_id=self.account_id,
            config=cloudflare.ZeroTrustTunnelCloudflaredConfigConfigArgs(
                ingresses=[
                    cloudflare.ZeroTrustTunnelCloudflaredConfigConfigIngressArgs(
                        hostname=rule.get("hostname"),
                        service=rule["service"],
                    )
                    for rule in ingress_rules
                ]
            ),
            opts=local_opts,
        )
        resources.append(tunnel_config)

        return resources
