# Kubernetes Configuration

KCL-based Kubernetes configuration with Flux GitOps.

## Structure

```
kubernetes/
├── bootstrap/           # Bootstrap Flux + ESO
├── clusters/            # Cluster definitions
│   ├── oci/
│   └── home/
├── apps/                # Applications by tenant
│   ├── infra/          # Infrastructure tenant
│   │   ├── _tenant/    # Tenant shared config
│   │   └── {app}/     # Apps
│   ├── o11y/          # Observability tenant
│   └── public/        # Public services tenant
└── konfig/            # KCL library
```

## Quick Start

### Prerequisites

- Kubernetes cluster
- kubectl configured
- KCL installed

### Bootstrap

```bash
# 1. Create doppler-credentials secret
kubectl create secret generic doppler-credentials \
  --from-literal=token=$DOPPLER_TOKEN \
  -n kube-system

# 2. Deploy bootstrap (Flux + ESO)
task bootstrap

# 3. Verify
kubectl get pods -n flux-system
kubectl get clustersecretstore
```

### Deploy an App

```bash
# Render app
task render-app TENANT=infra APP=authentik

# Deploy app
task deploy-app TENANT=infra APP=authentik
```

## Adding a New App

1. Create directory: `apps/{tenant}/{app}/base/`
2. Create `main.k`:

```kcl
# apps/infra/myapp/base/main.k

appName = "myapp"
namespace = "infra"

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
                "chart": "myapp"
                "version": "1.0.0"
                "sourceRef": {"kind": "HelmRepository", "name": "myapp"}
            }
        }
    }
}

result = [namespaceManifest, helmRelease]
```

## Tenants

| Tenant | Purpose | Examples |
|--------|---------|----------|
| infra | Infrastructure services | Authentik, PostgreSQL |
| o11y | Observability | Grafana, Loki, Prometheus |
| public | Public-facing services | Homepage, AdGuard |
| automation | Automation | n8n |

## Secrets

Secrets are managed via Doppler and synced by External Secrets Operator:

1. Secrets stored in Doppler
2. ExternalSecret CRD references Doppler
3. ESO syncs secrets to Kubernetes

### Adding Secrets

```yaml
# In your app's main.k
externalSecret = {
    "apiVersion": "external-secrets.io/v1beta1"
    "kind": "ExternalSecret"
    "metadata": {"name": "myapp-secrets", "namespace": "infra"}
    "spec": {
        "secretStoreRef": {"kind": "ClusterSecretStore", "name": "doppler"}
        "data": [
            {"secretKey": "MY_SECRET", "remoteRef": {"key": "MY_SECRET"}}
        ]
    }
}
```

## Flux

Flux automatically reconciles the cluster with Git:

- GitRepository: Watches this repo
- Kustomization: Applies changes on push

Enable Flux automation by adding:

```yaml
# In your app's Kustomization
spec:
  interval: 1h
  prune: True
  sourceRef:
    kind: GitRepository
    name: homelab
  path: apps/{tenant}/{app}
```
