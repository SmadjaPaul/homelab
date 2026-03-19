"""
Base classes for Homelab applications.

This module provides:
- BaseApp: Abstract base class for all apps
- NetworkPolicyBuilder: Builds network policies for apps
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any, Optional

import pulumi_kubernetes as k8s
import pulumi

from shared.utils.schemas import AppModel, ExposureMode


class BaseApp(ABC):
    """
    Abstract base class for all applications.

    Each app must define its model and implement deploy_components().
    The deploy() method handles namespace creation and network policies.
    """

    model: AppModel

    def __init__(self, model: AppModel):
        """Initialize base app with AppModel."""
        self._model = model

    def deploy(
        self,
        provider: k8s.Provider,
        config: dict[str, Any],
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> dict[str, Any]:
        """
        Deploy the application.

        Handles app-specific resources and network policies.
        Assumes namespace already exists.
        """
        print(
            f"  [BaseApp] Deploying {self._model.name} (test_network_policy={self._model.test.test_network_policy})"
        )
        result = {}

        def apply_standard_labels(args: pulumi.ResourceTransformationArgs):
            if isinstance(args.props, dict) and "metadata" in args.props:
                meta = args.props["metadata"]
                if meta is None:
                    meta = {}
                    args.props["metadata"] = meta

                # ObjectMetaArgs or Output — skip, can't mutate typed args
                if not isinstance(meta, dict):
                    return pulumi.ResourceTransformationResult(
                        props=args.props, opts=args.opts
                    )

                if "labels" not in meta or meta["labels"] is None:
                    meta["labels"] = {}

                meta["labels"]["homelab.smadja.dev/managed-by"] = "pulumi"
                meta["labels"]["homelab.smadja.dev/app"] = self._model.name
                meta["labels"]["homelab.smadja.dev/tier"] = self._model.tier.value

            return pulumi.ResourceTransformationResult(props=args.props, opts=args.opts)

        local_opts = pulumi.ResourceOptions.merge(
            opts or pulumi.ResourceOptions(),
            pulumi.ResourceOptions(transformations=[apply_standard_labels]),
        )

        components = self.deploy_components(provider, config, opts=local_opts)
        result.update(components)

        if self._model.test.test_network_policy:
            builder = NetworkPolicyBuilder(provider)
            result["network_policies"] = builder.build(self)

        result["model"] = self._model
        return result

    @abstractmethod
    def deploy_components(
        self,
        provider: k8s.Provider,
        config: dict[str, Any],
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> dict[str, Any]:
        """
        Deploy app-specific resources (helm releases, services, routes, etc.).

        Returns dict with keys like 'release', 'service', 'routes', etc.
        """
        pass

    def get_dependencies(self) -> list[str]:
        """Return list of dependencies (namespace names)."""
        return self._model.dependencies

    def get_secrets(self) -> list:
        """Return list of secrets required by this app."""
        return self._model.secrets

    def get_storage(self) -> list:
        """Return list of storage volumes needed."""
        return self._model.storage

    def get_test_config(self):
        """Return test configuration for this app."""
        return self._model.test

    def get_namespace(self) -> str:
        """Return the namespace for this app."""
        return self._model.namespace

    def get_name(self) -> str:
        """Return the name of this app."""
        return self._model.name


class NetworkPolicyBuilder:
    """
    Builds NetworkPolicies for applications.

    Default: Deny all, then allow explicit dependencies.
    """

    def __init__(self, provider: k8s.Provider):
        self.provider = provider

    def build(self, app: BaseApp) -> list:
        """
        Build NetworkPolicies for an app.
        """
        policies = []
        model = app._model
        namespace = model.namespace
        app_name = model.name
        dependencies = model.dependencies

        # 1. Deny all ingress and egress (default-deny)
        deny_all = k8s.networking.v1.NetworkPolicy(
            f"{app_name}-deny-all",
            metadata=k8s.meta.v1.ObjectMetaArgs(
                name=f"{app_name}-deny-all",
                namespace=namespace,
            ),
            spec=k8s.networking.v1.NetworkPolicySpecArgs(
                pod_selector=k8s.meta.v1.LabelSelectorArgs(),
                policy_types=["Ingress", "Egress"],
                ingress=[],
                egress=[],
            ),
            opts=pulumi.ResourceOptions(provider=self.provider),
        )
        policies.append(deny_all)

        # 2. Allow all ingress and egress WITHIN the same namespace
        allow_internal = k8s.networking.v1.NetworkPolicy(
            f"{app_name}-allow-internal",
            metadata=k8s.meta.v1.ObjectMetaArgs(
                name=f"{app_name}-allow-internal",
                namespace=namespace,
            ),
            spec=k8s.networking.v1.NetworkPolicySpecArgs(
                pod_selector=k8s.meta.v1.LabelSelectorArgs(),
                policy_types=["Ingress", "Egress"],
                ingress=[
                    k8s.networking.v1.NetworkPolicyIngressRuleArgs(
                        from_=[
                            k8s.networking.v1.NetworkPolicyPeerArgs(
                                pod_selector=k8s.meta.v1.LabelSelectorArgs(),
                            ),
                        ],
                    ),
                ],
                egress=[
                    k8s.networking.v1.NetworkPolicyEgressRuleArgs(
                        to=[
                            k8s.networking.v1.NetworkPolicyPeerArgs(
                                pod_selector=k8s.meta.v1.LabelSelectorArgs(),
                            ),
                        ],
                    ),
                ],
            ),
            opts=pulumi.ResourceOptions(provider=self.provider),
        )
        policies.append(allow_internal)

        # 3. Allow egress to DNS (kube-system)
        allow_dns = k8s.networking.v1.NetworkPolicy(
            f"{app_name}-allow-dns",
            metadata=k8s.meta.v1.ObjectMetaArgs(
                name=f"{app_name}-allow-dns",
                namespace=namespace,
            ),
            spec=k8s.networking.v1.NetworkPolicySpecArgs(
                pod_selector=k8s.meta.v1.LabelSelectorArgs(),
                policy_types=["Egress"],
                egress=[
                    k8s.networking.v1.NetworkPolicyEgressRuleArgs(
                        to=[
                            k8s.networking.v1.NetworkPolicyPeerArgs(
                                namespace_selector=k8s.meta.v1.LabelSelectorArgs(
                                    match_labels={"name": "kube-system"},
                                ),
                                pod_selector=k8s.meta.v1.LabelSelectorArgs(
                                    match_labels={"k8s-app": "kube-dns"},
                                ),
                            ),
                        ],
                    ),
                ],
            ),
            opts=pulumi.ResourceOptions(provider=self.provider),
        )
        policies.append(allow_dns)

        # 4. Allow egress to dependencies
        effective_deps = set(dependencies)
        if model.auth.enabled or model.auth.sso:
            effective_deps.add("authentik")

        for dep in effective_deps:
            full_name = f"{app_name}-allow-{dep}"
            allow_dep = k8s.networking.v1.NetworkPolicy(
                full_name,
                metadata=k8s.meta.v1.ObjectMetaArgs(
                    name=f"{app_name}-allow-{dep}",
                    namespace=namespace,
                ),
                spec=k8s.networking.v1.NetworkPolicySpecArgs(
                    pod_selector=k8s.meta.v1.LabelSelectorArgs(),
                    policy_types=["Egress"],
                    egress=[
                        k8s.networking.v1.NetworkPolicyEgressRuleArgs(
                            to=[
                                k8s.networking.v1.NetworkPolicyPeerArgs(
                                    namespace_selector=k8s.meta.v1.LabelSelectorArgs(
                                        match_labels={"name": dep},
                                    ),
                                ),
                            ],
                        ),
                    ],
                ),
                opts=pulumi.ResourceOptions(provider=self.provider),
            )
            policies.append(allow_dep)

        # 5. Allow egress to local CNPG database
        if model.persistence.database and model.persistence.database.local:
            allow_db = k8s.networking.v1.NetworkPolicy(
                f"{app_name}-allow-db",
                metadata=k8s.meta.v1.ObjectMetaArgs(
                    name=f"{app_name}-allow-db",
                    namespace=namespace,
                ),
                spec=k8s.networking.v1.NetworkPolicySpecArgs(
                    pod_selector=k8s.meta.v1.LabelSelectorArgs(),
                    policy_types=["Egress"],
                    egress=[
                        k8s.networking.v1.NetworkPolicyEgressRuleArgs(
                            to=[
                                k8s.networking.v1.NetworkPolicyPeerArgs(
                                    pod_selector=k8s.meta.v1.LabelSelectorArgs(
                                        match_labels={
                                            "cnpg.io/cluster": f"{app_name}-db"
                                        }
                                    )
                                )
                            ],
                            ports=[
                                k8s.networking.v1.NetworkPolicyPortArgs(
                                    protocol="TCP",
                                    port=5432,
                                )
                            ],
                        )
                    ],
                ),
                opts=pulumi.ResourceOptions(provider=self.provider),
            )
            policies.append(allow_db)

        # 6. Allow ingress from Cloudflare Tunnel or Authentik Outpost
        if model.network.hostname:
            mode = model.network.mode
            if mode in (ExposureMode.PUBLIC, ExposureMode.PROTECTED):
                ingress_sources = []

                if mode == ExposureMode.PUBLIC:
                    ingress_sources.append(
                        k8s.networking.v1.NetworkPolicyPeerArgs(
                            namespace_selector=k8s.meta.v1.LabelSelectorArgs(
                                match_labels={
                                    "kubernetes.io/metadata.name": "cloudflared"
                                }
                            ),
                        )
                    )
                elif mode == ExposureMode.PROTECTED:
                    ingress_sources.append(
                        k8s.networking.v1.NetworkPolicyPeerArgs(
                            namespace_selector=k8s.meta.v1.LabelSelectorArgs(
                                match_labels={
                                    "kubernetes.io/metadata.name": "authentik"
                                }
                            ),
                            pod_selector=k8s.meta.v1.LabelSelectorArgs(
                                match_expressions=[
                                    k8s.meta.v1.LabelSelectorRequirementArgs(
                                        key="app.kubernetes.io/name",
                                        operator="In",
                                        values=["authentik-outpost-proxy"],
                                    )
                                ]
                            ),
                        )
                    )

                allow_tunnel_ingress = k8s.networking.v1.NetworkPolicy(
                    f"{app_name}-allow-tunnel-ingress",
                    metadata=k8s.meta.v1.ObjectMetaArgs(
                        name=f"{app_name}-allow-tunnel-ingress",
                        namespace=namespace,
                    ),
                    spec=k8s.networking.v1.NetworkPolicySpecArgs(
                        pod_selector=k8s.meta.v1.LabelSelectorArgs(),
                        policy_types=["Ingress"],
                        ingress=[
                            k8s.networking.v1.NetworkPolicyIngressRuleArgs(
                                from_=ingress_sources,
                            ),
                        ],
                    ),
                    opts=pulumi.ResourceOptions(provider=self.provider),
                )
                policies.append(allow_tunnel_ingress)

        # 8. Allow external internet access
        if model.network.allow_external:
            include_internal = app_name == "cloudflared"
            policies.append(
                self.allow_external(
                    app_name,
                    namespace,
                    include_internal=include_internal,
                )
            )

        return policies

    def allow_external(
        self, app_name: str, namespace: str, include_internal: bool = False
    ) -> k8s.networking.v1.NetworkPolicy:
        """
        Create a NetworkPolicy that allows egress to the internet (0.0.0.0/0).
        Required for apps like cloudflared that need to reach external services.
        """
        egress_rules = [
            k8s.networking.v1.NetworkPolicyEgressRuleArgs(
                to=[
                    k8s.networking.v1.NetworkPolicyPeerArgs(
                        ip_block=k8s.networking.v1.IPBlockArgs(
                            cidr="0.0.0.0/0",
                            except_=["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],
                        ),
                    ),
                ],
            )
        ]

        if include_internal:
            # Add rule to allow all internal traffic between namespaces
            egress_rules.append(
                k8s.networking.v1.NetworkPolicyEgressRuleArgs(
                    to=[
                        k8s.networking.v1.NetworkPolicyPeerArgs(
                            namespace_selector=k8s.meta.v1.LabelSelectorArgs(),
                        ),
                    ],
                )
            )

        allow_external = k8s.networking.v1.NetworkPolicy(
            f"{app_name}-allow-external",
            metadata=k8s.meta.v1.ObjectMetaArgs(
                name=f"{app_name}-allow-external",
                namespace=namespace,
            ),
            spec=k8s.networking.v1.NetworkPolicySpecArgs(
                pod_selector=k8s.meta.v1.LabelSelectorArgs(),
                policy_types=["Egress"],
                egress=egress_rules,
            ),
            opts=pulumi.ResourceOptions(provider=self.provider),
        )
        return allow_external
