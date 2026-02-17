# Homepage - Dashboard
# =================
#
# Usage:
#   kcl run apps/public/homepage/base/main.k | kubectl apply -f-

appName = "homepage"
namespace = "public"

namespaceManifest = {
    "apiVersion": "v1"
    "kind": "Namespace"
    "metadata": {"name": namespace}
}

helmRelease = {
    "apiVersion": "helm.toolkit.fluxcd.io/v2beta1"
    "kind": "HelmRelease"
    "metadata": {"name": appName, "namespace": namespace}
    "spec": {
        "releaseName": appName
        "chart": {
            "spec": {
                "chart": "homepage"
                "version": "0.3.13"
                "sourceRef": {"kind": "HelmRepository", "name": "homepage"}
            }
        }
        "values": {
            "ingress": {
                "enabled": True
                "className": "traefik"
                "hosts": ["home.smadja.dev"]
                "tls": [{"secretName": "homepage-tls", "hosts": ["home.smadja.dev"]}]
            }
            "config": {
                "kubernetes": {
                    "enabled": True
                    "clusterName": "oci"
                }
            }
        }
    }
}

result = [namespaceManifest, helmRelease]
