# Homelab Kubernetes Architecture v2 (Platform v1.1)

## Overview

This architecture uses a **data-driven approach** where all applications and infrastructure are defined declaratively in `apps.yaml`, with Python code only for complex or custom logic.

## Design Principles

1. **Data-Driven**: Define apps, buckets, and identities in YAML, not Python
2. **Single Source of Truth**: `apps.yaml` drives all three Pulumi stacks
3. **Separation of Concerns**: Deployment vs Configuration vs Testing
4. **Dependency-Aware**: Topological sort ensures correct deployment order
5. **Fail-Fast**: Validate secrets exist in Doppler *before* any Kubernetes resource is created
6. **Provider Agnosticism**: Storage backends (S3, NAS) are abstracted via driver patterns

---

## Architecture Diagram

The system is split into three modular Pulumi stacks for clear separation of concerns:

```
                            ┌─────────────────┐
                            │    apps.yaml    │
                            │  apps | buckets │
                            │  identities     │
                            └────────┬────────┘
                                     │   (Read by all stacks)
                                     ▼
                      ┌─────────────────────────────┐
                      │          AppLoader          │
                      │  • filter by cluster        │
                      │  • topological sort         │
                      └──────────────┬──────────────┘
                                     │
           ┌─────────────────────────┼─────────────────────────┐
           ▼                         ▼                         ▼
  ┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
  │    k8s-core     │ ────▶ │   k8s-storage   │ ────▶ │    k8s-apps     │
  │   (Phase 1)     │       │    (Phase 2)    │       │    (Phase 3)    │
  ├─────────────────┤       ├─────────────────┤       ├─────────────────┤
  │ • Namespaces    │       │ • CSI Drivers   │       │ • AppRegistry   │
  │ • CRDs          │       │ • CloudNativePG │       │   (secrets,     │
  │ • Operators     │       │ • Redis Cache   │       │    storage,     │
  │   (ext-secrets, │       │ • S3 Buckets    │       │    routes,      │
  │    cert-manager │       │   (OCI/CF/etc.) │       │    auth)        │
  │    envoy-gw)    │       └────────┬────────┘       │ • GenericHelmApp│
  └─────────────────┘                │ s3_endpoints   │ • Custom Apps   │
                                     └───────────────▶└─────────────────┘
```

---

## Core Components

### 1. `AppModel` (`shared/utils/schemas.py`)

Unified configuration model for all applications:

| Field | Description |
|-------|-------------|
| `name`, `namespace` | Identity |
| `port`, `hostname`, `mode` | Network exposure |
| `category`, `tier` | Classification |
| `clusters`, `dependencies` | Deployment targeting |
| `helm` | Chart configuration (`chart`, `repo`, `version`, `values`, `values_file`) |
| `storage[]` | Persistent volumes (see `StorageConfig`) |
| `secrets[]` | Doppler → Kubernetes secret mappings (see `SecretRequirement`) |
| `database_backup` | S3-compatible backup target (see `BackupDestination`) |
| `test` | Test configuration (`expected_endpoints`, `network_isolation`, etc.) |

### 2. `S3BucketConfig` (`shared/utils/schemas.py`)

Defines an S3-compatible bucket managed by Pulumi, provider-agnostic:

| Field | Description |
|-------|-------------|
| `name` | Bucket name |
| `provider` | `oci` \| `cloudflare` \| `generic` |
| `purpose` | Semantic label (`backup`, `media`, `archive`, …) |
| `tier` | `Standard` \| `InfrequentAccess` \| `Archive` |
| `export_as` | Stack output key (consumed by `k8s-apps` via StackReference) |
| `access_key_secret` | Doppler key name for the S3 access key |
| `secret_key_secret` | Doppler key name for the S3 secret key |
| `endpoint_url` | Required for `provider: generic` (e.g., RustFS, MinIO) |
| `protect` | Prevent accidental deletion (default: `true` for backups) |

### 3. `SecretRequirement` (`shared/utils/schemas.py`)

Maps Kubernetes secret keys to Doppler:

```yaml
# Flat mapping (preferred): K8s key → Doppler key
secrets:
  - name: authentik-secrets
    keys:
      AUTHENTIK_SECRET_KEY: AUTHENTIK_SECRET_KEY
      AUTHENTIK_POSTGRESQL__PASSWORD: AUTHENTIK_POSTGRES_PASSWORD

# JSON parent mapping (legacy): all keys live inside a JSON blob
secrets:
  - name: hetzner-storage-creds
    keys: [username, password]
    remote_key: HETZNER_STORAGE_BOX_JSON_SECRET
```

### 4. `AppLoader` (`shared/apps/loader.py`)

Loads and validates `apps.yaml`:
- Parses YAML into `AppModel` (and `S3BucketConfig`, `IdentityUserModel`, etc.)
- Validates dependencies and detects cycles
- Provides **topological sort** for deployment order

### 5. `AppRegistry` & Sub-Registries (`shared/apps/common/`)

`ComponentResource` orchestrating cross-cutting concerns by delegating to specialized cohesive modules:

| Component | Implementation |
|---------|---------------|
| **`KubernetesRegistry`** | Pre-flight secret validation `pulumiverse-doppler` (Fail-Fast). RBAC, Monitoring, Database local cluster (CNPG), and Secrets (Creates `ExternalSecret` CRDs). |
| **`StorageRegistry`** | PVC creation via `StorageProvisionerFactory` (Strategy Pattern) and `StorageBoxManager` for Hetzner Box sub-accounts. |
| **`AuthentikRegistry`** | Users, Groups, Proxy/OAuth2 Providers via `pulumi-authentik`. Protected apps use `ProviderProxy` (mode=proxy); public apps with auth use `ProviderOauth2`. Handles Outpost Finalization (creates a `ServiceConnectionKubernetes` + `Outpost` (type=proxy)). |
| **`AppRegistry`** | The Facade component that orchestrates all three sub-registries during the deployment run. |
| **Exposure** | No-op: routing is managed centrally in k8s-apps via `ZeroTrustTunnelCloudflaredConfig` |

### 6. `S3Manager` (`shared/storage/s3_manager.py`)

Multi-provider S3 bucket provisioning with an **abstract driver pattern**:

| Driver | Provider | Notes |
|--------|----------|-------|
| `OciS3Driver` | Oracle Cloud Object Storage | Always-free 20 GB; S3-compatible endpoint |
| `CloudflareR2Driver` | Cloudflare R2 | Zero egress; good for media |
| `GenericS3Driver` | Any HTTP S3 endpoint | RustFS, MinIO, Garage — bucket must exist |

`S3Manager` orchestrates all configured buckets, exports a `s3_endpoints` dict consumed by `k8s-apps`.

### 7. Helm Values Adapters (`shared/apps/adapters/`)

`HelmValuesAdapter` interface and specific implementations (`HomarrAdapter`, `AuthentikAdapter`, `AppTemplateAdapter`). Replaces `if-else` blocks to dynamically mutate Helm values during app provisioning in a clean Strategy Pattern.

### 8. `GenericHelmApp` (`shared/apps/generic.py`)

Generic deployment for Helm-based apps. Leverages the `adapters` module to construct `helm.ReleaseArgs` seamlessly — no custom Python needed.

### 8. `BaseApp` (`shared/apps/base.py`)

Abstract base for custom apps:
- `deploy()`: Creates namespace + network policies
- `deploy_components()`: App-specific resources
- `NetworkPolicyBuilder`: Builds network isolation policies

---

## Deployment Flow

```
1. Deploy k8s-core
   - Creates all necessary namespaces dynamically from apps.yaml
   - Installs critical operators (CertManager, EnvoyGateway, ExternalSecrets)
   (Wait for ExternalSecrets CRDs to stabilize)

2. Deploy k8s-storage
   - Imports namespaces from k8s-core
   - Installs CSI drivers (Local Path, SMB) and Redis
   - Provisions database clusters (CNPG)
   - Provisions S3 buckets via S3Manager (OCI, Cloudflare R2, or Generic)
   - Exports: storage_classes, database_endpoints, redis_endpoints, s3_endpoints

3. Deploy k8s-apps
   Phase 1: Initialization
   - Imports namespaces, domain, database endpoints, and s3_endpoints
   - AppRegistry validates all Doppler secrets at preview time (Fail-Fast)
   - Initializes AppRegistry (Authentik SSO, StorageBoxManager)

   Phase 2: App Deployment
   - Iterates through apps in apps.yaml (topological order)
   - Deploys User Apps (GenericHelmApp or Custom Apps)
   - For each protected app: creates ProviderProxy + Application in Authentik
   - Collects proxy provider IDs for outpost binding

   Phase 3: Authentik Outpost Finalization
   - Creates ServiceConnectionKubernetes + Outpost (proxy type)
   - Binds all collected proxy provider IDs to the outpost
   - Outpost auto-deploys ak-outpost-* pod (port 9000)

   Phase 4: Cloudflare Tunnel Config
   - Reads CLOUDFLARE_TUNNEL_ID, CLOUDFLARE_ACCOUNT_ID from Doppler
   - Builds ingress rules dynamically from apps.yaml:
     * Protected apps → Authentik Outpost (:9000)
     * Public apps → direct service
   - Applies ZeroTrustTunnelCloudflaredConfig
```

### Authentication Flow (Protected Apps)

```
User → CF Tunnel → Authentik Outpost (:9000)
                         │
                    ┌────┴────┐
                    │ Has     │
                    │ Session?│
                    └────┬────┘
                    No   │   Yes
                    ↓    │    ↓
             Redirect    │   Proxy to
             to Authentik│   backend app
             login page  │
                    ↓    │
               User logs │
               in via    │
               auth.smadja.dev
                    ↓    │
               Set session cookie
               Redirect back
```

---

## Design Patterns

### 1. Data-Driven Pattern
Most apps need no Python code — just YAML:
```yaml
- name: homarr
  helm:
    chart: homarr
    repo: https://homarr-labs.github.io/charts/
    version: 2.0.0
```

### 2. Fail-Fast Secret Validation
At `pulumi preview`, `AppRegistry` fetches the Doppler secret map via `pulumiverse-doppler` and raises a `ValueError` if any required key is missing — before any Kubernetes resource is created:
```
ValueError: CRITICAL ERROR: Secret key 'OCI_S3_ACCESS_KEY' required by app 'authentik' is MISSING in Doppler...
```

### 3. Strategy / Factory Pattern (Storage)
`StorageProvisionerFactory` selects provisioner by `StorageConfig.storage_class`:
- `DefaultProvisioner`: Standard Kubernetes PVCs
- `HetznerSMBProvisioner`: Hetzner Storage Box sub-accounts

### 4. Abstract Driver Pattern (S3)
`S3Driver` is an abstract base; concrete drivers implement `provision(cfg, region) → BucketEndpoint`. `S3Manager` delegates to the right driver per bucket. Adding a new provider = one new driver class.

### 5. Component Resource Pattern
`AppRegistry` is a Pulumi ComponentResource — groups resources, manages dependencies, provides clear ownership.

---

## File Structure

```
.
├── apps.yaml                   # Single source of truth (apps, buckets, identities)
├── k8s-core/                   # Phase 1: Foundation (Namespaces, CRDs, Operators)
│   ├── Pulumi.yaml
│   ├── Pulumi.oci.yaml
│   └── __main__.py
├── k8s-storage/                # Phase 2: Storage & Databases
│   ├── Pulumi.yaml
│   ├── Pulumi.oci.yaml         # OCI config: ociNamespace, ociCompartmentId, ociRegion
│   └── __main__.py            # Calls S3Manager + exports s3_endpoints
├── k8s-apps/                   # Phase 3: User Applications
│   ├── Pulumi.yaml
│   ├── Pulumi.oci.yaml
│   └── __main__.py
├── shared/
│   ├── apps/
│   │   ├── base.py            # BaseApp, NetworkPolicyBuilder
│   │   ├── generic.py         # GenericHelmApp
│   │   ├── loader.py          # AppLoader (YAML → AppModel, topological sort)
│   │   ├── impl/              # Custom app implementations
│   │   └── common/
│   │       ├── registry.py    # AppRegistry (secrets, storage, auth, routes)
│   │       ├── storagebox.py  # Hetzner StorageBoxManager
│   │       └── storage_provisioner.py
│   ├── storage/
│   │   ├── __init__.py
│   │   └── s3_manager.py      # S3Manager + OCI/Cloudflare/Generic drivers
│   └── utils/
│       └── schemas.py         # AppModel, S3BucketConfig, SecretRequirement, …
├── tests/
│   ├── static/                # Pre-deployment validation (schemas, images, secrets)
│   ├── unit/                  # Pulumi mock unit tests
│   ├── integration/           # Post-deployment cluster checks
│   └── dynamic/               # Live cluster tests (routing, secrets, network)
├── policies/                  # Pulumi Crossguard policy packs
└── docs/
    └── ARCHITECTURE.md
```

---

## How to Add a New App

### Option 1: Simple Helm App (Recommended)

```yaml
# apps.yaml
- name: myapp
  category: public        # public | protected | internal | database
  tier: standard          # critical | standard | ephemeral
  namespace: homelab
  port: 8080
  hostname: myapp.smadja.dev
  mode: public
  clusters: [oci, local]
  dependencies: [external-secrets, envoy-gateway, kube-system]
  helm:
    chart: myapp
    repo: https://charts.example.com
    version: 1.0.0
  storage:
    - name: data
      size: 10Gi
      mount_path: /data
  secrets:
    - name: myapp-creds
      keys:
        api_key: MYAPP_API_KEY         # K8s key: Doppler key
        api_secret: MYAPP_API_SECRET
  test:
    routing: true
    expected_endpoints: [https://myapp.smadja.dev]
```

### Option 2: Add an S3 Bucket

```yaml
# apps.yaml — buckets section
buckets:
  - name: my-new-bucket
    provider: oci           # oci | cloudflare | generic
    purpose: media
    tier: Standard
    export_as: my_bucket    # exported in s3_endpoints stack output
    access_key_secret: OCI_S3_ACCESS_KEY   # Doppler key name
    secret_key_secret: OCI_S3_SECRET_KEY

  # For local/self-hosted RustFS or MinIO:
  - name: local-media
    provider: generic
    endpoint_url: https://rustfs.local.smadja.dev
    purpose: media
    export_as: local_media_bucket
    access_key_secret: RUSTFS_ACCESS_KEY
    secret_key_secret: RUSTFS_SECRET_KEY
```

### Option 3: Custom App

For complex apps requiring custom Kubernetes resources:

```python
# shared/apps/impl/myapp.py
from shared.apps.base import BaseApp
from shared.utils.schemas import AppModel

class MyApp(BaseApp):
    def __init__(self, model: AppModel):
        super().__init__(model)

    def deploy_components(self, provider, config, opts=None):
        # Custom deployment logic
        return {"release": ...}
```

---

## Secret Management

### Model

Secrets are defined in `apps.yaml` using `SecretRequirement`:

```yaml
secrets:
  - name: <k8s-secret-name>
    keys:
      <k8s-key>: <doppler-key>   # Flat mapping (preferred)
    # OR for JSON blobs in Doppler:
    keys: [key1, key2]
    remote_key: DOPPLER_JSON_SECRET_NAME
```

### Validation (Fail-Fast)

`AppRegistry` uses `pulumiverse-doppler` to fetch the full Doppler key map at `pulumi preview` time. If any referenced Doppler key does not exist, the entire preview fails immediately with a clear error message, before touching the cluster.

### Credential locations

| What | Where |
|------|-------|
| Doppler token | Pulumi stack config (`homelab:dopplerToken`) |
| OCI S3 credentials | Doppler: `OCI_S3_ACCESS_KEY`, `OCI_S3_SECRET_KEY` |
| Cloudflare API token | Doppler: `CLOUDFLARE_API_TOKEN` |
| Hetzner token | Env var `HETZNER_API_TOKEN` (set before `pulumi up`) |

---

## Testing Strategy

| Layer | Tool | What it checks |
|-------|------|---------------|
| Static | `pytest tests/static/` | Schema validation, secret mapping, image tags |
| Unit | `pytest tests/unit/` | Pulumi mock tests (dependency graph, storage logic) |
| Policy | `pulumi policy run` | Security contexts, TLS, resource limits |
| Dynamic | `pytest tests/dynamic/` | Live routing, secret sync, network policies |
| Pre-flight | `pulumi preview` | Doppler key existence (via `pulumiverse-doppler`) |

```bash
pytest tests/static/ -v        # Pre-deployment checks
pytest tests/dynamic/ -v       # Post-deployment cluster checks
```
