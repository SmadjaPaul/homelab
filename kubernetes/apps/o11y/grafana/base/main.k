# Grafana - Observability Dashboard
# ================================
#
# Usage:
#   kcl run apps/o11y/grafana/base/main.k | kubectl apply -f-

appName = "grafana"
namespace = "o11y"

namespaceManifest = {
    "apiVersion": "v1"
    "kind": "Namespace"
    "metadata": {"name": namespace}
}

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
            {"secretKey": "GRAFANA_ADMIN_USER", "remoteRef": {"key": "GRAFANA_ADMIN_USER"}}
            {"secretKey": "GRAFANA_ADMIN_PASSWORD", "remoteRef": {"key": "GRAFANA_ADMIN_PASSWORD"}}
        ]
    }
}

helmRelease = {
    "apiVersion": "helm.toolkit.fluxcd.io/v2beta1"
    "kind": "HelmRelease"
    "metadata": {"name": appName, "namespace": namespace}
    "spec": {
        "releaseName": appName
        "chart": {
            "spec": {
                "chart": "grafana"
                "version": "8.4.3"
                "sourceRef": {"kind": "HelmRepository", "name": "grafana"}
            }
        }
        "values": {
            "admin": {
                "existingSecret": "grafana-secrets"
                "userKey": "GRAFANA_ADMIN_USER"
                "passwordKey": "GRAFANA_ADMIN_PASSWORD"
            }
            "ingress": {
                "enabled": True
                "className": "traefik"
                "hosts": ["grafana.smadja.dev"]
                "tls": [{"secretName": "grafana-tls", "hosts": ["grafana.smadja.dev"]}]
            }
            "persistence": {
                "enabled": True
                "size": "10Gi"
            }
        }
    }
}

result = [namespaceManifest, externalSecret, helmRelease]
