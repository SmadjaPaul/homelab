"""
Unified Application Registry and Tunnel Manager.

Orchestrates all cross-cutting concerns for application deployment:
- KubernetesRegistry: Secrets, RBAC, Monitoring, Database
- StorageRegistry: PVC creation, Hetzner Storage Box
- AuthentikRegistry: SSO providers, Outpost
- TunnelManager: Cloudflare Tunnel routing (DNS is auto-discovered by external-dns)

RELATED FILES:
  - k8s-apps/__main__.py: Entry point that calls this registry
  - shared/networking/cloudflare/exposure_manager.py: TunnelManager implementation
  - shared/apps/common/authentik_registry.py: SSO configuration
  - apps.yaml: Source of truth for all applications
"""

import pulumi
import pulumi_kubernetes as k8s
import pulumi_cloudflare as cloudflare
from typing import List, Dict, Any, Optional
import pulumiverse_doppler as doppler
from shared.utils.schemas import AppModel

from shared.apps.common.kubernetes_registry import KubernetesRegistry
from shared.apps.common.storage_registry import StorageRegistry
from shared.apps.common.authentik_registry import AuthentikRegistry
from shared.networking.cloudflare.exposure_manager import TunnelManager


class AppRegistry(pulumi.ComponentResource):
    """
    Manages application deployment lifecycle using composition.
    Delegates to specialized sub-registries for K8s, Storage, Auth, and Tunnel concerns.
    """

    def __init__(
        self,
        name: str,
        provider: k8s.Provider,
        config: Optional[Dict[str, Any]] = None,
        opts: Optional[pulumi.ResourceOptions] = None,
    ):
        super().__init__("homelab:common:AppRegistry", name, {}, opts)
        self.register_outputs({})

        self.provider = provider
        self.config = config or {}
        domain = self.config.get("domain", "smadja.dev")

        doppler_config = pulumi.Config("homelab")
        doppler_token = doppler_config.get_secret("dopplerToken")

        doppler_provider = None
        if doppler_token:
            doppler_provider = doppler.Provider(
                f"{name}-doppler-provider",
                doppler_token=doppler_token,
                opts=pulumi.ResourceOptions(parent=self),
            )

        self.doppler_secrets = doppler.get_secrets_output(
            project="infrastructure",
            config="prd",
            opts=pulumi.InvokeOptions(provider=doppler_provider),
        )

        self.k8s_registry = KubernetesRegistry(provider, self.doppler_secrets, self)
        self.storage_registry = StorageRegistry(provider, self.config, self)
        self.auth_registry = AuthentikRegistry(
            self.config, domain, self, doppler_provider
        )

        # Tunnel management (Cloudflare) — DNS is handled by external-dns
        self.tunnel_manager = None
        account_id = self.config.get("cloudflare_account_id")
        tunnel_id = self.config.get("cloudflare_tunnel_id")
        cf_token = self.config.get("cloudflare_api_token")
        zone_id = self.config.get("cloudflare_zone_id")

        if account_id and tunnel_id and cf_token:
            cf_provider = cloudflare.Provider(
                f"{name}-cloudflare-provider",
                api_token=cf_token,
                opts=pulumi.ResourceOptions(parent=self),
            )
            self.tunnel_manager = TunnelManager(
                account_id, tunnel_id, domain, cf_provider, self, zone_id=zone_id
            )

        self.namespaces: Dict[str, k8s.core.v1.Namespace] = {}

    def get_or_create_namespace(
        self, namespace_name: str, tier: str
    ) -> k8s.core.v1.Namespace:
        """Centralized namespace management with URN deduplication."""
        core_namespaces = ["default", "kube-system", "kube-public", "kube-node-lease"]
        if namespace_name in core_namespaces:
            return None

        if namespace_name not in self.namespaces:
            self.namespaces[namespace_name] = k8s.core.v1.Namespace(
                f"ns-{namespace_name}",
                metadata=k8s.meta.v1.ObjectMetaArgs(
                    name=namespace_name,
                    labels={"name": namespace_name},
                ),
                opts=pulumi.ResourceOptions(
                    provider=self.provider,
                    parent=self,
                    delete_before_replace=True,
                    protect=tier == "critical",
                ),
            )
        return self.namespaces[namespace_name]

    def setup_global_infrastructure(self):
        """Setup resources that are cluster-wide or shared."""
        self.k8s_registry.wait_for_crds()
        self.storage_registry.setup_storagebox_automation()

        # Initialize shared database cluster
        local_opts = pulumi.ResourceOptions(provider=self.provider, parent=self)
        self.k8s_registry.setup_shared_database_cluster(local_opts)

        # Cleanup evicted/failed pods to prevent DiskPressure cascades
        self.k8s_registry.setup_pod_cleanup_cronjob(local_opts)

    def register_app(
        self,
        app: AppModel,
        deployed_apps: Optional[Dict[str, Any]] = None,
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> List[pulumi.Resource]:
        """Provision all registry-managed resources for a single application."""
        resources = []
        deployed_apps = deployed_apps or {}
        pulumi.Output.from_input(app.name).apply(
            lambda name: print(f"  [Registry] Registering {name} in {app.namespace}...")
        )

        local_opts = pulumi.ResourceOptions(provider=self.provider, parent=self)

        # Ensure namespace exists
        ns_res = self.get_or_create_namespace(app.namespace, app.tier.value)
        if ns_res:
            local_opts = pulumi.ResourceOptions.merge(
                local_opts, pulumi.ResourceOptions(depends_on=[ns_res])
            )
        if self.k8s_registry.crd_wait_cmd:
            local_opts = pulumi.ResourceOptions.merge(
                local_opts,
                pulumi.ResourceOptions(depends_on=[self.k8s_registry.crd_wait_cmd]),
            )
        if opts:
            local_opts = pulumi.ResourceOptions.merge(local_opts, opts)

        resources.extend(
            self.k8s_registry.setup_secrets_for_app(app, deployed_apps, local_opts)
        )
        resources.extend(self.k8s_registry.setup_docker_secrets(app, local_opts))
        resources.extend(self.k8s_registry.setup_rbac_for_app(app, local_opts))
        resources.extend(self.k8s_registry.setup_reliability_for_app(app, local_opts))
        resources.extend(
            self.k8s_registry.setup_monitoring_for_app(app, deployed_apps, local_opts)
        )
        resources.extend(
            self.storage_registry.setup_storage_for_app(app, deployed_apps, local_opts)
        )
        resources.extend(self.k8s_registry.setup_database_for_app(app, local_opts))

        return resources

    def configure_authentik_layer(
        self,
        apps: List[AppModel],
        authentik_provider: pulumi.ProviderResource,
        opts: pulumi.ResourceOptions,
    ) -> List[pulumi.Resource]:
        """Phase 2: Provision Authentik Proxy or OAuth2 Providers and Applications for all apps."""
        # Identities are now managed via AuthentikDirectory or specialized adapters
        return self.auth_registry.configure_authentik_layer(
            apps, authentik_provider, opts
        )

    def finalize_authentik_outpost(
        self,
        authentik_provider: pulumi.ProviderResource,
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> List[pulumi.Resource]:
        """Create the Authentik Outpost after all apps have been registered."""
        return self.auth_registry.finalize_authentik_outpost(authentik_provider, opts)

    def setup_tunnel_layer(self, apps: List[AppModel]) -> List[pulumi.Resource]:
        """Step 3c: Configure Cloudflare Tunnel routing for all apps.
        DNS records are handled by external-dns (auto-discovery from Authentik Outpost Ingress).
        """
        if not self.tunnel_manager:
            pulumi.log.warn(
                "TunnelManager not initialized (missing Cloudflare config). Skipping tunnel setup."
            )
            return []

        return self.tunnel_manager.setup_tunnel(apps)
