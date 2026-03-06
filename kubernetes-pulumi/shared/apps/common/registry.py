"""
Unified Application Registry and Exposure Manager
"""

import pulumi
import pulumi_kubernetes as k8s
from typing import List, Dict, Any, Optional
import pulumiverse_doppler as doppler
from shared.utils.schemas import AppModel

from shared.apps.common.kubernetes_registry import KubernetesRegistry
from shared.apps.common.storage_registry import StorageRegistry
from shared.apps.common.authentik_registry import AuthentikRegistry


class AppRegistry(pulumi.ComponentResource):
    """
    Manages exposure (Public/Protected/Internal) and Secret requirements using composition.
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
        self.auth_registry = AuthentikRegistry(self.config, domain, self)

    def setup_global_infrastructure(self):
        """Setup resources that are cluster-wide or shared."""
        self.k8s_registry.wait_for_crds()
        self.storage_registry.setup_storagebox_automation()

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
        # Fix legacy identites config
        self.auth_registry.setup_identities(authentik_provider)
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
