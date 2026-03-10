"""
Custom implementation for Cloudflared.
Deploys the Cloudflare Tunnel pod (cloudflared) which connects to the Cloudflare
edge and forwards traffic to applications in the cluster.

NOTE: This file deploys the TUNNEL POD only. The tunnel ROUTING RULES
(which hostnames map to which services) are configured separately.

RELATED FILES:
  - shared/networking/cloudflare/exposure_manager.py: TunnelManager — configures tunnel routing
  - shared/apps/common/authentik_registry.py: Creates the Authentik Outpost that receives tunnel traffic
  - apps.yaml: Source of truth — add `cloudflared` as a dependency for exposed apps
"""

from typing import Any, Dict, Optional
import pulumi
import pulumi_kubernetes as k8s
from shared.apps.base import BaseApp
from shared.utils.schemas import AppModel


class CloudflaredApp(BaseApp):
    """
    Manually deploys Cloudflare Tunnel resources.
    """

    def deploy_components(
        self,
        provider: k8s.Provider,
        config: Dict[str, Any],
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> Dict[str, Any]:
        app_name = self._model.name
        namespace = self._model.namespace

        # Service Account
        sa = k8s.core.v1.ServiceAccount(
            f"{app_name}-sa",
            metadata=k8s.meta.v1.ObjectMetaArgs(
                name=f"sa-{app_name}",
                namespace=namespace,
            ),
            opts=pulumi.ResourceOptions.merge(
                opts, pulumi.ResourceOptions(provider=provider)
            ),
        )

        # Deployment
        deployment = k8s.apps.v1.Deployment(
            f"{app_name}-deployment",
            metadata=k8s.meta.v1.ObjectMetaArgs(
                name=f"{app_name}-tunnel",
                namespace=namespace,
                labels={
                    "app.kubernetes.io/name": "cloudflared",
                    "app.kubernetes.io/instance": app_name,
                },
            ),
            spec=k8s.apps.v1.DeploymentSpecArgs(
                replicas=2,
                selector=k8s.meta.v1.LabelSelectorArgs(
                    match_labels={"pod": "cloudflared"}
                ),
                template=k8s.core.v1.PodTemplateSpecArgs(
                    metadata=k8s.meta.v1.ObjectMetaArgs(labels={"pod": "cloudflared"}),
                    spec=k8s.core.v1.PodSpecArgs(
                        service_account_name=sa.metadata.name,
                        containers=[
                            k8s.core.v1.ContainerArgs(
                                name="cloudflared",
                                image="docker.io/cloudflare/cloudflared:2024.8.3",
                                args=[
                                    "tunnel",
                                    "--no-autoupdate",
                                    "--metrics",
                                    "0.0.0.0:2000",
                                    "run",
                                ],
                                env=[
                                    k8s.core.v1.EnvVarArgs(
                                        name="TUNNEL_TOKEN",
                                        value_from=k8s.core.v1.EnvVarSourceArgs(
                                            secret_key_ref=k8s.core.v1.SecretKeySelectorArgs(
                                                name="cloudflared-tunnel-doppler",
                                                key="tunnelToken",
                                            )
                                        ),
                                    )
                                ],
                                liveness_probe=k8s.core.v1.ProbeArgs(
                                    http_get=k8s.core.v1.HTTPGetActionArgs(
                                        path="/ready", port=2000
                                    ),
                                    failure_threshold=1,
                                    initial_delay_seconds=10,
                                    period_seconds=10,
                                ),
                                security_context=k8s.core.v1.SecurityContextArgs(
                                    run_as_non_root=True,
                                    run_as_user=65532,
                                    allow_privilege_escalation=False,
                                    capabilities=k8s.core.v1.CapabilitiesArgs(
                                        drop=["ALL"]
                                    ),
                                    read_only_root_filesystem=True,
                                ),
                            )
                        ],
                    ),
                ),
            ),
            opts=pulumi.ResourceOptions.merge(
                opts, pulumi.ResourceOptions(provider=provider)
            ),
        )

        return {"deployment": deployment, "service_account": sa}


def create_app(model: AppModel) -> CloudflaredApp:
    return CloudflaredApp(model)
