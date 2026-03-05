"""
Custom implementation for external-secrets.
Deploys the Helm chart and configures the Doppler ClusterSecretStore.
"""

from typing import Any, Dict, Optional

import os
import pulumi
import pulumi_kubernetes as k8s

from shared.apps.generic import GenericHelmApp
from shared.utils.schemas import AppModel


from pulumi.dynamic import Resource, ResourceProvider, CreateResult
import time


class WaiterProvider(ResourceProvider):
    def create(self, props):
        print("  [ExternalSecretsApp] Waiting 15 seconds for webhooks to be ready...")
        time.sleep(15)
        return CreateResult(id_="waiter", outs=props)


class Waiter(Resource):
    def __init__(self, name, opts=None):
        super().__init__(WaiterProvider(), name, {}, opts)


class ExternalSecretsApp(GenericHelmApp):
    """
    Extends GenericHelmApp to add a ClusterSecretStore for Doppler.
    Assumes a Secret named 'doppler-token-auth-api' exists in the namespace.
    """

    def deploy_components(
        self,
        provider: k8s.Provider,
        config: Dict[str, Any],
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> Dict[str, Any]:
        # 1. Get Doppler Token securely
        # Priority: Pulumi Config Secret > Env Var
        project_config = pulumi.Config("homelab")
        doppler_token = project_config.get_secret("dopplerToken") or os.environ.get(
            "DOPPLER_TOKEN"
        )

        if not doppler_token:
            pulumi.log.warn(
                f"Doppler token not found for {self._model.name}. Ensure 'homelab:dopplerToken' is set or DOPPLER_TOKEN env var is present."
            )
            doppler_secret = None
        else:
            # 2. Create the Secret required by Doppler provider
            doppler_secret = k8s.core.v1.Secret(
                "doppler-token-auth-api",
                metadata={
                    "name": "doppler-token-auth-api",
                    "namespace": self._model.namespace,
                },
                string_data={
                    "dopplerToken": doppler_token,
                },
                opts=pulumi.ResourceOptions(provider=provider),
            )

        # 3. Deploy standard Helm chart
        result = super().deploy_components(provider, config, opts=opts)
        release = result["release"]

        # Wait for webhooks to be ready
        waiter = Waiter(
            "webhook-waiter", opts=pulumi.ResourceOptions(depends_on=[release])
        )

        # 4. Create ClusterSecretStore for Doppler
        doppler_project = config.get("dopplerProject", "infrastructure")
        doppler_config = config.get("dopplerConfig", "prd")

        print(
            f"  [ExternalSecretsApp] Creating ClusterSecretStore doppler (Project: {doppler_project}, Config: {doppler_config})..."
        )
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
                        "project": doppler_project,
                        "config": doppler_config,
                        "auth": {
                            "secretRef": {
                                "dopplerToken": {
                                    "name": "doppler-token-auth-api",
                                    "key": "dopplerToken",
                                    "namespace": self._model.namespace,
                                }
                            }
                        },
                    }
                }
            },
            opts=pulumi.ResourceOptions(
                provider=provider,
                depends_on=[waiter, doppler_secret] if doppler_secret else [waiter],
            ),
        )
        print("  [ExternalSecretsApp] Created ClusterSecretStore doppler")

        result["cluster_secret_store"] = css
        return result


def create_app(model: AppModel) -> ExternalSecretsApp:
    return ExternalSecretsApp(model)
