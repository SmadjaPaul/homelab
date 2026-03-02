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

from shared.utils.schemas import AppModel


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
        opts: Optional[pulumi.ResourceOptions] = None
    ) -> dict[str, Any]:
        """
        Deploy the application.

        Handles app-specific resources and network policies.
        Assumes namespace already exists.
        """
        result = {}

        components = self.deploy_components(provider, config, opts=opts)
        result.update(components)

        if self._model.test.test_network_policy:
            builder = NetworkPolicyBuilder(provider)
            policies = builder.build(self)
            result["network_policies"] = policies

        result["model"] = self._model
        return result


    @abstractmethod
    def deploy_components(
        self,
        provider: k8s.Provider,
        config: dict[str, Any],
        opts: Optional[pulumi.ResourceOptions] = None
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

        Creates:
        1. Deny-all ingress/egress
        2. Allow DNS (kube-system)
        3. Allow egress to dependencies
        """
        policies = []
        namespace = app.get_namespace()
        app_name = app.get_name()
        dependencies = app.get_dependencies()

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

        # 3. Allow egress to dependencies
        for dep in dependencies:
            allow_dep = k8s.networking.v1.NetworkPolicy(
                f"{app_name}-allow-{dep}",
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

        return policies
