"""
GenericHelmApp - Generic Helm-based application.

Automatically deploys helm charts from AppModel.
Only apps with complex custom resources need custom Python code.
"""

from typing import Any

import pulumi
import pulumi_kubernetes as k8s
import pulumi_kubernetes.helm.v3 as helm

from apps.base import BaseApp
from utils.schemas import AppModel


class GenericHelmApp(BaseApp):
    """
    Generic Helm application.

    Reads configuration from AppModel and automatically:
    - Deploys Helm chart
    - Creates PVCs for storage
    """

    def __init__(self, model: AppModel):
        super().__init__(model)
        self._gateway_name = "envoy-gateway"

    def deploy_components(
        self,
        provider: k8s.Provider,
        config: dict[str, Any]
    ) -> dict[str, Any]:
        """Deploy the app using Helm."""

        result = {}

        # Load external values_file if provided
        final_values = self._model.values.copy()

        # Inject standard best practices into values
        defaults = {
            "serviceAccount": {
                "create": False, # Registry creates it
                "name": self._model.name,
            },
            "resources": self._model.resources.model_dump(),
            "replicaCount": self._model.replicas,
            "terminationGracePeriodSeconds": self._model.termination_grace_period,
        }

        # Deep merge/update (simplified)
        for k, v in defaults.items():
            if k not in final_values:
                final_values[k] = v

        if self._model.values_file:
            try:
                import yaml
                import os

                values_path = self._model.values_file
                if not os.path.isabs(values_path):
                    # Assume relative to project root if not absolute
                    project_root = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
                    values_path = os.path.join(project_root, values_path)

                with open(values_path, 'r') as f:
                    file_values = yaml.safe_load(f) or {}

                # Merge dictionaries (shallow merge/update for simplicity, you can expand if needed)
                # For a deep merge, we'd iterate over dicts recursively.
                final_values.update(file_values)
                print(f"  [GenericApp] Loaded values_file {self._model.values_file} for {self._model.name}")
            except Exception as e:
                print(f"Warning: Failed to load values_file {self._model.values_file} for {self._model.name}: {e}")

        # Deploy Helm chart
        release = helm.Release(
            self._model.name,
            chart=self._model.chart,
            version=self._model.version,
            namespace=self._model.namespace,
            repository_opts=helm.RepositoryOptsArgs(
                repo=self._model.repo,
            ),
            values=final_values,
            opts=pulumi.ResourceOptions(provider=provider),
        )
        result["release"] = release

        return result


def create_generic_app(model: AppModel) -> GenericHelmApp:
    """Factory to create GenericHelmApp from AppModel."""
    return GenericHelmApp(model)
