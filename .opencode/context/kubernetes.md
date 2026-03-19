<!-- Context: kubernetes | Priority: high | Version: 2.0 | Updated: 2026-03-13 -->

# Kubernetes & Pulumi (IaC)

## Core Concepts

- **Pulumi (Python)** manages the entire Kubernetes deployment. Manual `kubectl apply` is for debugging only.
- **Data-Driven**: The single source of truth is `kubernetes-pulumi/apps.yaml`. Python code is strictly for infrastructure scaffolding and dynamic resource generation.
- **Fail-Fast**: Secret validation happens at `pulumi preview` time via `pulumiverse-doppler`. Pulumi fails immediately if secrets are missing.

## Directory Structure (`/kubernetes-puli`)

```
kubernetes-pulumi/
├── apps.yaml                   # Single source of truth (apps, buckets, identities)
├── k8s-core/                   # Phase 1: Namespaces, CRDs, Operators
│   └── ext-secrets, cert-manager, envoy-gateway
├── k8s-storage/                # Phase 2: Storage, Databases, S3
│   ├── CloudNativePG (homelab-db - 2x50GB)
│   ├── Redis (local-path)
│   └── S3 Buckets (OCI, R2, Generic)
├── k8s-apps/                   # Phase 3: Applications & Authentik SSO
└── shared/
    ├── apps/
    │   ├── base.py             # BaseApp, NetworkPolicyBuilder
    │   ├── generic.py          # GenericHelmApp
    │   ├── loader.py           # AppLoader (topological sort)
    │   └── common/             # AppRegistry, AuthentikRegistry, StorageRegistry
    ├── storage/
    │   └── s3_manager.py       # OCI/R2/Generic drivers
    └── utils/
        └── schemas.py           # AppModel, S3BucketConfig, SecretRequirement
```

## Deployment Order

1. **k8s-core** → Namespaces, CRDs, Operators
2. **k8s-storage** → Databases (CNPG), Redis, S3 buckets
3. **k8s-apps** → Applications, Authentik, Tunnel config

## Adding a New Application

1. **Define in apps.yaml**:
   ```yaml
   - name: myapp
     namespace: homelab
     hostname: myapp.smadja.dev
     mode: protected  # or public
     helm:
       chart: myapp
       repo: https://charts.example.com
       version: 1.0.0
     secrets:
       - name: myapp-creds
         keys:
           api_key: MYAPP_API_KEY
   ```
2. **Deploy**: `cd k8s-apps && pulumi up`

## Key Components

| Component | Purpose |
|-----------|---------|
| **AppLoader** | Loads YAML, validates deps, topological sort |
| **AppRegistry** | Orchestrates secrets, storage, auth |
| **AuthentikRegistry** | Users, Groups, Proxy Providers |
| **TunnelManager** | Cloudflare Tunnel ingress rules |
| **S3Manager** | Multi-provider S3 (OCI, R2, Generic) |

## Common Operations

- Preview: `pulumi preview`
- Apply: `pulumi up`
- Stack selection: `pulumi stack select dev|prod`
