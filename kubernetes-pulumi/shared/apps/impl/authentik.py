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
        # Start with base values from GenericHelmApp (which uses AuthentikAdapter)
        base_values = super().get_final_values()

        # Specialized values for Authentik
        custom_values = {
            "postgresql": {
                "enabled": False,
            },
            "redis": {
                "enabled": False,
            },
            "authentik": {
                "redis": {
                    "host": "redis.storage.svc.cluster.local",
                    "port": 6379,
                },
                "existingSecret": {"secretName": "authentik-vars"},
            },
        }

        # Handle any logic that might be missing from the adapter but was here
        # E.g. forced per-component env overrides if needed, but the adapter
        # now handles this via _inject_extra_env into server/worker blocks.

        # Merge dicts ensures specialized logic takes precedence
        return self._merge_dicts(base_values, custom_values)

    def deploy_components(
        self,
        provider: k8s.Provider,
        config: Dict[str, Any],
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> Dict[str, Any]:
        """Deploy standard Helm chart."""
        return super().deploy_components(provider, config, opts=opts)

    def _merge_dicts(self, dict1: Dict, dict2: Dict) -> Dict:
        """Deep merge two dictionaries."""
        result = dict1.copy()
        for key, value in dict2.items():
            if (
                key in result
                and isinstance(result[key], dict)
                and isinstance(value, dict)
            ):
                result[key] = self._merge_dicts(result[key], value)
            else:
                result[key] = value
        return result


def create_app(model: AppModel) -> AuthentikApp:
    return AuthentikApp(model)
