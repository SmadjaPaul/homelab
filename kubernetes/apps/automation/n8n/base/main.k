# n8n - Workflow Automation
# =======================
#
# Usage:
#   kcl run apps/automation/n8n/base/main.k | kubectl apply -f-

appName = "n8n"
namespace = "automation"

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
            {"secretKey": "N8N_ENCRYPTION_KEY", "remoteRef": {"key": "N8N_ENCRYPTION_KEY"}}
            {"secretKey": "N8N_BASIC_AUTH_ACTIVE", "remoteRef": {"key": "N8N_BASIC_AUTH_ACTIVE"}}
            {"secretKey": "N8N_BASIC_AUTH_USER", "remoteRef": {"key": "N8N_BASIC_AUTH_USER"}}
            {"secretKey": "N8N_BASIC_AUTH_PASSWORD", "remoteRef": {"key": "N8N_BASIC_AUTH_PASSWORD"}}
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
                "chart": "n8n"
                "version": "0.26.0"
                "sourceRef": {"kind": "HelmRepository", "name": "n8n"}
            }
        }
        "values": {
            "n8n": {
                "baseUrl": "https://n8n.smadja.dev"
            }
            "ingress": {
                "enabled": True
                "className": "traefik"
                "hosts": ["n8n.smadja.dev"]
                "tls": [{"secretName": "n8n-tls", "hosts": ["n8n.smadja.dev"]}]
            }
            "persistence": {
                "enabled": True
                "size": "10Gi"
            }
        }
    }
}

result = [namespaceManifest, externalSecret, helmRelease]
