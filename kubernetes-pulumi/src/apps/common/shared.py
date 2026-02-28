"""
Shared Services - Postgres, Redis, and Service Registry.

Provides abstractions for shared infrastructure services.
Apps can request dependencies without knowing implementation details.
"""

import pulumi
import pulumi_kubernetes as k8s
from typing import Optional
from enum import Enum


class ServiceType(Enum):
    POSTGRES = "postgres"
    REDIS = "redis"


class SharedService:
    """Base class for shared service implementations."""
    def __init__(self, name: str, provider: k8s.Provider, namespace: str):
        self.name = name
        self.provider = provider
        self.namespace = namespace


class PostgresService(SharedService):
    """PostgreSQL service using CloudNativePG."""

    def __init__(
        self,
        name: str,
        provider: k8s.Provider,
        namespace: str = "cnpg-system",
        storage_class: str = "oci-bv",
        storage_size: str = "10Gi",
    ):
        super().__init__(name, provider, namespace)
        self.storage_class = storage_class
        self.storage_size = storage_size

        self.cluster = k8s.apiextensions.CustomResource(
            f"{name}-cluster",
            api_version="postgresql.cnpg.io/v1",
            kind="Cluster",
            metadata={"name": name, "namespace": namespace},
            spec={
                "instances": 1,
                "imageName": "ghcr.io/cloudnative-pg/postgresql:17.5",
                "superuserSecret": {"name": f"{name}-superuser"},
                "bootstrap": {"initdb": {"database": "appdb", "owner": "appuser"}},
                "storage": {"size": storage_size, "storageClass": storage_class},
            },
            opts=pulumi.ResourceOptions(provider=provider),
        )

    def get_host(self) -> str:
        return f"{self.name}.{self.namespace}.svc.cluster.local"

    def get_port(self) -> int:
        return 5432

    def get_connection_string(self, database: str = "appdb") -> str:
        return f"postgresql://appuser@{self.get_host()}:{self.get_port()}/{database}"


class RedisService(SharedService):
    """Redis service using Bitnami chart."""

    def __init__(
        self,
        name: str,
        provider: k8s.Provider,
        namespace: str = "redis",
    ):
        super().__init__(name, provider, namespace)

        self.release = k8s.helm.v3.Release(
            name,
            chart="redis",
            version="20.6.0",
            namespace=namespace,
            repository_opts=k8s.helm.v3.RepositoryOptsArgs(repo="https://charts.bitnami.com/bitnami"),
            values={"architecture": "standalone", "auth": {"enabled": False}},
            opts=pulumi.ResourceOptions(provider=provider),
        )

    def get_host(self) -> str:
        return f"{self.name}-master.{self.namespace}.svc.cluster.local"

    def get_port(self) -> int:
        return 6379

    def get_url(self) -> str:
        return f"redis://{self.get_host()}:{self.get_port()}"


class ServiceRegistry:
    """
    Central registry for shared services.
    Allows apps to request dependencies (PostgreSQL, Redis) on demand.
    """
    _services: dict[str, object] = {}

    @classmethod
    def get_or_create_postgres(
        cls,
        name: str,
        provider: k8s.Provider,
        namespace: str = "cnpg-system",
        storage_class: str = "oci-bv",
        storage_size: str = "10Gi",
    ) -> PostgresService:
        """Get or create a PostgreSQL instance."""
        if name in cls._services:
            return cls._services[name]

        service = PostgresService(
            name=name,
            provider=provider,
            namespace=namespace,
            storage_class=storage_class,
            storage_size=storage_size,
        )
        cls._services[name] = service
        return service

    @classmethod
    def get_or_create_redis(
        cls,
        name: str,
        provider: k8s.Provider,
        namespace: str = "redis",
    ) -> RedisService:
        """Get or create a Redis instance."""
        if name in cls._services:
            return cls._services[name]

        service = RedisService(name=name, provider=provider, namespace=namespace)
        cls._services[name] = service
        return service
