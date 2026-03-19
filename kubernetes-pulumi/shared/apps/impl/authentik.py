"""
Custom implementation for Authentik.
Provisions a CloudNative-PG Cluster for its database and configures the Helm chart
to use the shared Redis instance and the newly created Postgres cluster.
"""

from typing import Any, Dict, Optional

import pulumi
import pulumi_kubernetes as k8s

from shared.apps.generic import GenericHelmApp
from shared.utils.schemas import AppModel


class AuthentikApp(GenericHelmApp):
    def get_final_values(self) -> Dict[str, Any]:
        """Provides the final dictionary of Helm values specifically for Authentik."""
        # Now relies entirely on AuthentikAdapter for all logic including Redis/DB
        return super().get_final_values()

    def deploy_components(
        self,
        provider: k8s.Provider,
        config: Dict[str, Any],
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> Dict[str, Any]:
        """Deploy standard Helm chart."""
        return super().deploy_components(provider, config, opts=opts)


def create_app(model: AppModel) -> AuthentikApp:
    return AuthentikApp(model)
