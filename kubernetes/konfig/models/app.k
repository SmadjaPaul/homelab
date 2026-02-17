# App Model - Simple version without functions
# ===========================================

schema App:
    name: str
    namespace: str
    tenantName?: str = "default"
    chart?: HelmChart
    values?: {str:}

schema HelmChart:
    name: str
    version: str
    repository: str

schema DopplerConfig:
    project: str
    keys: [str]

_helmRepos = {
    "traefik": "https://traefik.github.io/charts"
    "cert-manager": "https://charts.jetstack.io"
    "external-secrets": "https://charts.external-secrets.io"
    "flux": "https://fluxcd-community.github.io/helm-charts"
    "grafana": "https://grafana.github.io/helm-charts"
    "authentik": "https://charts.goauthentik.io"
    "n8n": "https://n8n-io.github.io/n8n-helm-chart"
    "homepage": "https://homepage.github.io/helm-charts"
}
