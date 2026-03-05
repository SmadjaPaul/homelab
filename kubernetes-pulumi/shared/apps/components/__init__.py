"""
Pulumi Component Resources for Kubernetes Applications

This module provides high-level ComponentResources that encapsulate
complex application stacks with their dependencies.

Classes:
    - AuthentikEnvironment: Authentik + PostgreSQL + Redis
    - DatabaseCluster: CNPG PostgreSQL cluster
    - ApplicationStack: Generic application with storage and secrets
"""

from __future__ import annotations

import pulumi
import pulumi_kubernetes as k8s
from typing import Optional, Dict, Any, List


class DatabaseCluster(pulumi.ComponentResource):
    """
    PostgreSQL cluster using CloudNativePG.

    This component creates:
    - Namespace (if specified)
    - CNPG Cluster
    - Database and user
    - Secrets for superuser and application access

    Usage:
        db = DatabaseCluster(
            name="authentik-db",
            provider=provider,
            namespace="cnpg-system",
            storage_class="oci-bv",
            storage_size="10Gi",
        )
        db.get_connection_string()  # Returns connection string
    """

    def __init__(
        self,
        name: str,
        provider: k8s.Provider,
        namespace: str = "cnpg-system",
        storage_class: str = "oci-bv",
        storage_size: str = "10Gi",
        instances: int = 1,
        postgres_version: str = "17.5",
        opts: Optional[pulumi.ResourceOptions] = None,
    ):
        super().__init__("homelab:component:DatabaseCluster", name, {}, opts)

        self.name = name
        self.namespace = namespace
        self.provider = provider

        # Create namespace if it doesn't exist
        self.ns = k8s.core.v1.Namespace(
            f"{name}-ns",
            metadata={"name": namespace},
            opts=pulumi.ResourceOptions(provider=provider, parent=self),
        )

        # Generate passwords
        superuser_password = pulumi.secret(
            pulumi.RandomPassword(
                f"{name}-superuser-pw",
                length=32,
            )
        )

        app_password = pulumi.secret(
            pulumi.RandomPassword(
                f"{name}-app-pw",
                length=32,
            )
        )

        # Create secrets
        self.superuser_secret = k8s.core.v1.Secret(
            f"{name}-superuser",
            metadata={
                "name": f"{name}-superuser",
                "namespace": namespace,
            },
            string_data={
                "username": "postgres",
                "password": superuser_password.result,
            },
            opts=pulumi.ResourceOptions(provider=provider, parent=self),
        )

        self.app_secret = k8s.core.v1.Secret(
            f"{name}-app",
            metadata={
                "name": f"{name}-app",
                "namespace": namespace,
            },
            string_data={
                "database": "appdb",
                "username": "appuser",
                "password": app_password.result,
            },
            opts=pulumi.ResourceOptions(provider=provider, parent=self),
        )

        # Create CNPG Cluster
        self.cluster = k8s.apiextensions.CustomResource(
            f"{name}-cluster",
            api_version="postgresql.cnpg.io/v1",
            kind="Cluster",
            metadata={
                "name": name,
                "namespace": namespace,
            },
            spec={
                "instances": instances,
                "imageName": f"ghcr.io/cloudnative-pg/postgresql:{postgres_version}",
                "superuserSecret": {"name": f"{name}-superuser"},
                "bootstrap": {
                    "initdb": {
                        "database": "appdb",
                        "owner": "appuser",
                        "secret": {"name": f"{name}-app"},
                    }
                },
                "storage": {
                    "size": storage_size,
                    "storageClass": storage_class,
                },
            },
            opts=pulumi.ResourceOptions(
                provider=provider,
                parent=self,
                depends_on=[self.ns],
            ),
        )

        # Export outputs
        self.connection_string = pulumi.Output.concat(
            "postgresql://appuser:",
            app_password.result,
            "@",
            name,
            ".",
            namespace,
            ".svc.cluster.local:5432/appdb",
        )

        pulumi.export(f"{name}_connection_string", self.connection_string)
        pulumi.export(f"{name}_host", f"{name}.{namespace}.svc.cluster.local")
        pulumi.export(f"{name}_port", 5432)

    def get_connection_string(self, database: str = "appdb") -> str:
        """Get the PostgreSQL connection string."""
        return self.connection_string

    def get_host(self) -> str:
        """Get the database host."""
        return f"{self.name}.{self.namespace}.svc.cluster.local"

    def get_port(self) -> int:
        """Get the database port."""
        return 5432


class RedisInstance(pulumi.ComponentResource):
    """
    Redis instance using Bitnami Helm chart.

    This component creates:
    - Namespace
    - Redis deployment (standalone or cluster mode)
    - Service
    """

    def __init__(
        self,
        name: str,
        provider: k8s.Provider,
        namespace: str = "redis",
        architecture: str = "standalone",
        auth_enabled: bool = False,
        opts: Optional[pulumi.ResourceOptions] = None,
    ):
        super().__init__("homelab:component:RedisInstance", name, {}, opts)

        self.name = name
        self.namespace = namespace
        self.provider = provider

        # Create namespace
        self.ns = k8s.core.v1.Namespace(
            f"{name}-ns",
            metadata={"name": namespace},
            opts=pulumi.ResourceOptions(provider=provider, parent=self),
        )

        # Deploy Redis via Helm
        self.release = k8s.helm.v3.Release(
            name,
            chart="redis",
            version="20.6.0",
            namespace=namespace,
            repository_opts=k8s.helm.v3.RepositoryOptsArgs(
                repo="https://charts.bitnami.com/bitnami"
            ),
            values={
                "architecture": architecture,
                "auth": {"enabled": auth_enabled},
                "service": {
                    "ports": {
                        "redis": 6379,
                    }
                },
            },
            opts=pulumi.ResourceOptions(
                provider=provider,
                parent=self,
                depends_on=[self.ns],
            ),
        )

        # Export outputs
        service_name = f"{name}-master"
        self.host = f"{service_name}.{namespace}.svc.cluster.local"
        self.port = 6379

        pulumi.export(f"{name}_host", self.host)
        pulumi.export(f"{name}_port", self.port)

    def get_host(self) -> str:
        """Get Redis host."""
        return self.host

    def get_port(self) -> int:
        """Get Redis port."""
        return self.port

    def get_url(self) -> str:
        """Get Redis URL."""
        return f"redis://{self.host}:{self.port}"


class ApplicationStack(pulumi.ComponentResource):
    """
    Generic application stack with storage, secrets, and routing.

    This component encapsulates:
    - Namespace creation
    - Helm chart deployment
    - PersistentVolumeClaims
    - ExternalSecrets integration
    - Network policies (optional)

    Usage:
        app = ApplicationStack(
            name="myapp",
            provider=provider,
            namespace="homelab",
            chart={"name": "myapp", "repo": "...", "version": "1.0.0"},
            storage=[{"name": "data", "size": "10Gi", "mount_path": "/data"}],
            secrets=[{"name": "creds", "keys": ["api_key"], "remote_key": "MYAPP_CREDS"}],
        )
    """

    def __init__(
        self,
        name: str,
        provider: k8s.Provider,
        namespace: str,
        chart: Dict[str, Any],
        config: Optional[Dict[str, Any]] = None,
        storage: Optional[List[Dict[str, Any]]] = None,
        secrets: Optional[List[Dict[str, Any]]] = None,
        replicas: int = 1,
        opts: Optional[pulumi.ResourceOptions] = None,
    ):
        super().__init__("homelab:component:ApplicationStack", name, {}, opts)

        self.name = name
        self.namespace = namespace
        self.provider = provider
        self.storage_claims = {}

        # Create namespace
        self.ns = k8s.core.v1.Namespace(
            f"{name}-ns",
            metadata={"name": namespace},
            opts=pulumi.ResourceOptions(provider=provider, parent=self),
        )

        # Create ServiceAccount
        self.sa = k8s.core.v1.ServiceAccount(
            f"{name}-sa",
            metadata={
                "name": name,
                "namespace": namespace,
            },
            opts=pulumi.ResourceOptions(provider=provider, parent=self),
        )

        # Create PVCs for storage
        if storage:
            for idx, storage_spec in enumerate(storage):
                storage_name = storage_spec.get("name", f"data-{idx}")
                pvc = self._create_pvc(storage_name, storage_spec)
                self.storage_claims[storage_name] = pvc

        # Create ExternalSecrets
        if secrets:
            self._create_secrets(secrets)

        # Deploy Helm chart
        chart_values = chart.get("values", {})
        if config:
            chart_values.update(config)

        self.release = k8s.helm.v3.Release(
            name,
            chart=chart.get("name"),
            version=chart.get("version"),
            namespace=namespace,
            repository_opts=k8s.helm.v3.RepositoryOptsArgs(repo=chart.get("repo", "")),
            values=chart_values,
            opts=pulumi.ResourceOptions(
                provider=provider,
                parent=self,
                depends_on=[self.ns],
            ),
        )

        # Create PodDisruptionBudget if replicas > 1
        if replicas > 1:
            self.pdb = k8s.policy.v1.PodDisruptionBudget(
                f"{name}-pdb",
                metadata={
                    "name": name,
                    "namespace": namespace,
                },
                spec={
                    "maxUnavailable": 1,
                    "selector": {"matchLabels": {"app.kubernetes.io/name": name}},
                },
                opts=pulumi.ResourceOptions(provider=provider, parent=self),
            )

        # Export outputs
        pulumi.export(f"{name}_namespace", namespace)
        pulumi.export(f"{name}_release_status", self.release.status)

    def _create_pvc(
        self, name: str, spec: Dict[str, Any]
    ) -> k8s.core.v1.PersistentVolumeClaim:
        """Create a PersistentVolumeClaim."""
        return k8s.core.v1.PersistentVolumeClaim(
            f"{name}-pvc",
            metadata={
                "name": name,
                "namespace": self.namespace,
            },
            spec={
                "accessModes": [spec.get("access", "ReadWriteOnce")],
                "resources": {"requests": {"storage": spec.get("size", "1Gi")}},
                "storageClassName": spec.get("storage_class"),
            },
            opts=pulumi.ResourceOptions(
                provider=self.provider,
                parent=self,
            ),
        )

    def _create_secrets(self, secrets: List[Dict[str, Any]]):
        """Create ExternalSecrets for the application."""
        for secret_spec in secrets:
            secret_name = secret_spec.get("name", "app-secrets")
            remote_key = secret_spec.get("remote_key", secret_name)
            keys = secret_spec.get("keys", [])

            k8s.apiextensions.CustomResource(
                f"{self.name}-secret-{secret_name}",
                api_version="external-secrets.io/v1beta1",
                kind="ExternalSecret",
                metadata={
                    "name": secret_name,
                    "namespace": self.namespace,
                },
                spec={
                    "refreshInterval": "1h",
                    "secretStoreRef": {
                        "kind": "ClusterSecretStore",
                        "name": "doppler",
                    },
                    "target": {"name": secret_name, "creationPolicy": "Owner"},
                    "data": [
                        {
                            "secretKey": key,
                            "remoteRef": {"key": remote_key, "property": key},
                        }
                        for key in keys
                    ],
                },
                opts=pulumi.ResourceOptions(
                    provider=self.provider,
                    parent=self,
                ),
            )
