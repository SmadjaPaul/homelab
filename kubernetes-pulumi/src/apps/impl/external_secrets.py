"""
Custom implementation for external-secrets.
Deploys the Helm chart and configures the Doppler ClusterSecretStore.
"""

from typing import Any, Dict

import os
import pulumi
import pulumi_kubernetes as k8s

from apps.generic import GenericHelmApp
from utils.schemas import AppModel


class ExternalSecretsApp(GenericHelmApp):
    """
    Extends GenericHelmApp to add a ClusterSecretStore for Doppler.
    Assumes a Secret named 'doppler-token-auth-api' exists in the namespace.
    """

    def deploy_components(self, provider: k8s.Provider, config: Dict[str, Any]) -> Dict[str, Any]:
        # 1. Get Doppler Token securely
        # Priority: Pulumi Config Secret > Env Var
        project_config = pulumi.Config("homelab")
        doppler_token = project_config.get_secret("dopplerToken") or os.environ.get("DOPPLER_TOKEN")

        if not doppler_token:
            pulumi.log.warn(f"Doppler token not found for {self._model.name}. Ensure 'homelab:dopplerToken' is set or DOPPLER_TOKEN env var is present.")
            # We continue, but ClusterSecretStore might fail if the secret doesn't exist
        else:
            # 2. Create the Secret required by Doppler provider
            k8s.core.v1.Secret(
                "doppler-token-auth-api",
                metadata={
                    "name": "doppler-token-auth-api",
                    "namespace": self._model.namespace,
                },
                string_data={
                    "dopplerToken": doppler_token,
                },
                opts=pulumi.ResourceOptions(provider=provider, parent=self),
            )

        # 3. Deploy standard Helm chart
        result = super().deploy_components(provider, config)
        release = result["release"]

        # 4. Create ClusterSecretStore for Doppler
        css = k8s.apiextensions.CustomResource(
            "doppler-cluster-secret-store",
            api_version="external-secrets.io/v1beta1",
            kind="ClusterSecretStore",
            metadata={
                "name": "doppler",
            },
            spec={
                "provider": {
                    "doppler": {
                        "auth": {
                            "secretRef": {
                                "dopplerToken": {
                                    "name": "doppler-token-auth-api",
                                    "key": "dopplerToken",
                                    "namespace": self._model.namespace,
                                }
                            }
                        }
                    }
                }
            },
            opts=pulumi.ResourceOptions(provider=provider, depends_on=[release], parent=self),
        )

        result["cluster_secret_store"] = css
        return result


def create_app(model: AppModel) -> ExternalSecretsApp:
    return ExternalSecretsApp(model)
