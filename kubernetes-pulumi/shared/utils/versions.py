"""
Centralized version constants for all Helm charts
Migrated from kubernetes/VERSIONS.md
"""

from typing import TypedDict, Any


class ChartVersion(TypedDict):
    chart: str
    app: str


class FluxVersion(TypedDict):
    version: str


# Using Any to avoid type conflicts between ChartVersion and FluxVersion
VERSIONS: dict[str, Any] = {
    # Infrastructure
    "cloudflared": {"chart": "2.2.7", "app": "2026.2.0"},
    "external_dns": {"chart": "1.20.0", "app": "0.20.0"},
    "external_secrets": {"chart": "2.0.1", "app": "2.0.1"},
    "cert_manager": {"chart": "1.19.3", "app": "1.19.4"},
    # Storage
    "cloudnative_pg": {"chart": "0.27.1", "app": "1.27.1"},
    "redis": {"chart": "20.6.0", "app": "7.4.1"},
    "longhorn": {"chart": "1.8.0", "app": "v1.8.0"},
    "monitoring": {"chart": "3.8.0", "app": "0.12.0"},  # grafana/k8s-monitoring
    "velero": {"chart": "8.3.0", "app": "v1.15.2"},
    # Security
    "authentik": {"chart": "2026.2.0", "app": "2026.2.0"},
    "vaultwarden": {"chart": "3.2.1", "app": "1.33.2"},
    "kyverno": {"chart": "3.3.4", "app": "1.13.4"},
    "kyverno_policies": {"chart": "3.3.2", "app": "1.13.0"},
    # Public
    "homarr": {"chart": "8.12.0", "app": "v1.53.0"},
    # Media
    "audiobookshelf": {"chart": "3.2.1", "app": "2.12.1"},
    "immich": {"chart": "0.10.3", "app": "2.0.0"},
    "lidarr": {"chart": "5.6.1", "app": "2.5.1"},
    # Automation
    "n8n": {"chart": "0.28.1", "app": "1.92.2"},
    "prowlarr": {"chart": "2.8.1", "app": "1.31.2"},
    "sonarr": {"chart": "5.6.1", "app": "4.0.13"},
    "radarr": {"chart": "10.6.1", "app": "5.19.3"},
    "navidrome": {"chart": "0.14.0", "app": "0.53.3"},
    "slskd": {"chart": "0.1.0", "app": "0.20.0"},
    # Business
    "outline": {"chart": "1.8.1", "app": "0.77.0"},
    "vikunja": {"chart": "0.23.1", "app": "0.24.2"},
    "paperless_ngx": {"chart": "5.1.0", "app": "2.2.1"},
    "umami": {"chart": "3.1.0", "app": "2.17.0"},
    # Network
    "netbird": {"chart": "0.31.1", "app": "0.30.0"},
    # Observability
    "k8s_monitoring": {"chart": "2.1.0", "app": "0.9.1"},
    # Flux
    "flux": {"version": "2.8.0"},
    # vCluster
    "vcluster": {"chart": "0.22.0", "app": "0.20.0"},
    # envoy-gateway (Gateway API implementation - CNCF)
    "envoy_gateway": {"chart": "1.6.1", "app": "v1.6.1"},
    # Dex (OIDC Provider)
    "dex": {"chart": "0.24.0", "app": "v2.41.0"},
}


# Helm repositories
class HelmRepos:
    BITNAMI = "https://charts.bitnami.com/bitnami"
    GRAFANA = "https://grafana.github.io/helm-charts"
    JETSTACK = "https://charts.jetstack.io"
    EXTERNAL_DNS = "https://kubernetes-sigs.github.io/external-dns"
    AUTHENTIK = "https://charts.goauthentik.io"
    KUBEWARDEN = "https://charts.kubewarden.io"
    VCLUSTER = "https://charts.loft.sh"
    K8S_AT_HOME = "https://k8s-at-home.com/charts"
    EXTERNAL_SECRETS = "https://charts.external-secrets.io"
    TRUECHARTS = "https://truecharts.org"
    CLOUDFLARED = "https://community-charts.github.io/helm-charts"
    CLOUDNATIVE_PG = "https://cloudnative-pg.github.io/charts"
    HOMARR_LABS = "https://homarr-labs.github.io/charts"
    # envoy-gateway (Gateway API implementation - CNCF)
    ENVOY_GATEWAY = "oci://docker.io/envoyproxy"
    # Dex (OIDC Provider)
    DEX = "https://charts.dexidp.io"
    # Cert-manager
    CERT_MANAGER = "https://charts.jetstack.io"
    # Longhorn
    LONGHORN = "https://charts.longhorn.io"
    # Monitoring (Grafana Cloud)
    GRAFANA = "https://grafana.github.io/helm-charts"
    PROMETHEUS_COMMUNITY = "https://prometheus-community.github.io/helm-charts"
    # Velero (VMware)
    VELERO = "https://vmware-tanzu.github.io/helm-charts"
    # Media Stack (k8s-at-home is deprecated, using alternatives or TrueCharts if available, but usually community-driven)
    # Using generic repositories or specific app ones
    BJW_S = "https://bjw-s-labs.github.io/helm-charts"  # Common for ARR apps
    OAUTH2_PROXY = "https://oauth2-proxy.github.io/manifests"
    # Authentik
    AUTHENTIK = "https://charts.goauthentik.io"


# Storage classes
class StorageClasses:
    OCI_BV = "oci-bv"
    LOCAL_PATH = "local-path"
    NFS = "nfs"
    DEFAULT = ""
