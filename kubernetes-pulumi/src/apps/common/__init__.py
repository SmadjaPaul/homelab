"""
Common Kubernetes constructs.
"""

from apps.common.builders import (
    create_namespace,
    create_service,
    create_pvc,
    create_ingress,
    create_secret,
    create_configmap,
)

from apps.common.shared import (
    PostgresService,
    RedisService,
    ServiceRegistry,
    ServiceType,
)

from apps.common.registry import AppRegistry

__all__ = [
    # Builders
    "create_namespace",
    "create_service",
    "create_pvc",
    "create_ingress",
    "create_secret",
    "create_configmap",
    # Shared services
    "PostgresService",
    "RedisService",
    "ServiceRegistry",
    "ServiceType",
    # Registry
    "AppRegistry",
]
