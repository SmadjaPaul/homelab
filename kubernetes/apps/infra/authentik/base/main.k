# Authentik - Identity Provider
# =============================

import konfig.models.cluster as cluster

# Cluster configuration
oci = cluster.ociCluster
domain = oci.domain

appName = "authentik"
namespace = "infra"

# Namespace manifest
namespaceManifest = {
    "apiVersion": "v1"
    "kind": "Namespace"
    "metadata": {"name": namespace}
}

# ExternalSecret manifest
externalSecret = {
    "apiVersion": "external-secrets.io/v1beta1"
    "kind": "ExternalSecret"
    "metadata": {
        "name": "{}-secrets".format(appName)
        "namespace": namespace
    }
    "spec": {
        "refreshInterval": "1h"
        "secretStoreRef": {"kind": "ClusterSecretStore", "name": "doppler"}
        "target": {"name": "{}-secrets".format(appName), "creationPolicy": "Owner"}
        "data": [
            {"secretKey": "AUTHENTIK_SECRET_KEY", "remoteRef": {"key": "AUTHENTIK_SECRET_KEY"}}
            {"secretKey": "AUTHENTIK_POSTGRES_PASSWORD", "remoteRef": {"key": "AUTHENTIK_POSTGRES_PASSWORD"}}
        ]
    }
}

# HelmRelease manifest
helmRelease = {
    "apiVersion": "helm.toolkit.fluxcd.io/v2beta1"
    "kind": "HelmRelease"
    "metadata": {"name": appName, "namespace": namespace}
    "spec": {
        "releaseName": appName
        "chart": {
            "spec": {
                "chart": "authentik"
                "version": "2024.10.3"
                "sourceRef": {"kind": "HelmRepository", "name": "authentik"}
            }
        }
        "values": {
            "authentik": {
                "secret_key": "secret-key-placeholder"
            }
            "postgresql": {
                "enabled": True
                "auth": {
                    "database": "authentik"
                    "username": "authentik"
                }
            }
            "redis": {"enabled": True}
            "ingress": {
                "enabled": True
                "className": "traefik"
                "hosts": ["auth." + domain]
                "tls": [{"secretName": "authentik-tls", "hosts": ["auth." + domain]}]
            }
        }
        "dependsOn": [{"name": "external-secrets"}]
    }
}

result = [namespaceManifest, externalSecret, helmRelease]
