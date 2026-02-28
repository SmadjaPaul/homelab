"""
Kubernetes Resource Builders.

Helpers for creating common Kubernetes resources.
"""

import pulumi
import pulumi_kubernetes as k8s
from typing import Optional


def create_namespace(
    name: str,
    provider: k8s.Provider,
    labels: Optional[dict] = None,
) -> k8s.core.v1.Namespace:
    """Create a Kubernetes namespace with standard labels."""
    default_labels = {
        "app.kubernetes.io/name": name,
        "app.kubernetes.io/part-of": name,
    }
    if labels:
        default_labels.update(labels)

    return k8s.core.v1.Namespace(
        name,
        metadata={"name": name, "labels": default_labels},
        opts=pulumi.ResourceOptions(provider=provider),
    )


def create_service(
    name: str,
    namespace: str,
    port: int,
    provider: k8s.Provider,
    service_type: str = "ClusterIP",
    selector: Optional[dict] = None,
) -> k8s.core.v1.Service:
    """Create a Kubernetes Service."""
    default_selector = {"app.kubernetes.io/name": name}
    if selector:
        default_selector.update(selector)

    return k8s.core.v1.Service(
        name,
        metadata={"name": name, "namespace": namespace, "labels": default_selector},
        spec={
            "type": service_type,
            "ports": [{"name": "http", "port": port, "targetPort": str(port)}],
            "selector": default_selector,
        },
        opts=pulumi.ResourceOptions(provider=provider),
    )


def create_pvc(
    name: str,
    namespace: str,
    size: str,
    provider: k8s.Provider,
    storage_class: Optional[str] = None,
) -> k8s.core.v1.PersistentVolumeClaim:
    """Create a PersistentVolumeClaim."""
    spec = {
        "accessModes": ["ReadWriteOnce"],
        "resources": {"requests": {"storage": size}},
    }
    if storage_class:
        spec["storageClassName"] = storage_class

    return k8s.core.v1.PersistentVolumeClaim(
        name,
        metadata={"name": name, "namespace": namespace, "labels": {"app.kubernetes.io/name": name}},
        spec=spec,
        opts=pulumi.ResourceOptions(provider=provider),
    )


def create_ingress(
    name: str,
    namespace: str,
    host: str,
    service_name: str,
    service_port: int,
    provider: k8s.Provider,
    ingress_class: str = "traefik",
) -> k8s.networking.v1.Ingress:
    """Create a Kubernetes Ingress."""
    return k8s.networking.v1.Ingress(
        name,
        metadata={
            "name": name,
            "namespace": namespace,
            "labels": {"app.kubernetes.io/name": name},
            "annotations": {"kubernetes.io/ingress.class": ingress_class},
        },
        spec={
            "ingressClassName": ingress_class,
            "rules": [{
                "host": host,
                "http": {
                    "paths": [{
                        "path": "/",
                        "pathType": "Prefix",
                        "backend": {
                            "service": {
                                "name": service_name,
                                "port": {"number": service_port},
                            },
                        },
                    }],
                },
            }],
        },
        opts=pulumi.ResourceOptions(provider=provider),
    )


def create_secret(
    name: str,
    namespace: str,
    data: dict[str, str],
    provider: k8s.Provider,
    type: str = "Opaque",
) -> k8s.core.v1.Secret:
    """Create a Kubernetes Secret."""
    return k8s.core.v1.Secret(
        name,
        metadata={"name": name, "namespace": namespace},
        type=type,
        string_data=data,
        opts=pulumi.ResourceOptions(provider=provider),
    )


def create_configmap(
    name: str,
    namespace: str,
    data: dict[str, str],
    provider: k8s.Provider,
) -> k8s.core.v1.ConfigMap:
    """Create a Kubernetes ConfigMap."""
    return k8s.core.v1.ConfigMap(
        name,
        metadata={"name": name, "namespace": namespace, "labels": {"app.kubernetes.io/name": name}},
        data=data,
        opts=pulumi.ResourceOptions(provider=provider),
    )
