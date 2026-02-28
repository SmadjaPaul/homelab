# Homelab Kubernetes Architecture v2

## Overview

This architecture uses a **data-driven approach** where most applications are defined declaratively in `apps.yaml`, with Python code only for complex or custom implementations.

## Design Principles

1. **Data-Driven**: Define apps in YAML, not Python
2. **Single Source of Truth**: One model (`AppModel`) for configuration
3. **Separation of Concerns**: Deployment vs Configuration vs Testing
4. **Dependency-Aware**: Topological sort ensures correct deployment order

## Core Components

### 1. AppModel (utils/schemas.py)

Unified configuration model for all applications. Contains:

- **Identity**: name, namespace
- **Network**: port, hostname, mode (public/protected/internal)
- **Classification**: category, tier
- **Deployment**: clusters, dependencies
- **Configuration**: chart, repo, version, values, `values_file`
- **Exposure Flags**: `disable_auto_route`
- **Resources**: storage (with `existing_claim`, `shared`), secrets
- **Testing**: test configuration

### 2. AppLoader (apps/loader.py)

Loads and validates `apps.yaml`:

- Parses YAML into AppModel
- Validates dependencies
- Detects cyclic dependencies
- Provides **topological sort** for deployment order

### 3. AppRegistry (apps/common/registry.py)

ComponentResource that orchestrates cross-cutting concerns:

- **Secrets**: Creates ExternalSecrets from Doppler
- **Storage**: Orchestrates PVC creation via `StorageProvisionerFactory` (Strategy Pattern)
- **Hetzner Automation**: Provisions sub-accounts for users via `StorageBoxManager`
- **Auth & Identity**: Provisions Authentik Users, Groups, and OAuth2 Apps via `pulumi-authentik`
- **Exposure**: Creates HTTPRoutes or Tunnel ingresses

### 4. GenericHelmApp (apps/generic.py)

Generic deployment for Helm-based apps:

- Deploys Helm chart from AppModel
- No custom Python needed

### 5. BaseApp (apps/base.py)

Abstract base for custom apps:

- `deploy()`: Creates namespace + network policies
- `deploy_components()`: App-specific resources
- `NetworkPolicyBuilder`: Builds network isolation policies

### 6. Custom Apps (apps/impl/)

Apps requiring complex logic:

- Kanidm: Custom resources (Certificate, ConfigMap, Deployment)

## Architecture Diagram

```
                    ┌─────────────────┐
                    │    apps.yaml    │
                    │ (Configuration) │
                    └────────┬────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                        AppLoader                             │
│  • load() → list[AppModel]                                 │
│  • validate() → (bool, error)                              │
│  • get_deployment_order() → topological sort               │
└─────────────────────────────────────────────────────────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
       ┌──────────┐  ┌──────────┐  ┌──────────┐
       │ Generic  │  │ AppRegistry │  │ Custom   │
       │HelmApp   │  │            │  │ Apps     │
       └──────────┘  └──────────┘  └──────────┘
              │              │              │
              ▼              ▼              ▼
       ┌──────────┐  ┌──────────┐  ┌──────────┐
       │  Helm    │  │ Secrets  │  │ Custom   │
       │ Release  │  │ Storage  │  │Resources │
       └──────────┘  │ Auth    │  └──────────┘
                     │ Routes  │
                     └──────────┘
```

## Deployment Flow

```
1. Load apps.yaml
2. Validate (schema + dependencies)
3. Get deployment order (topological sort)
4. For each app in order:
   a. AppRegistry handles cross-cutting concerns
   b. GenericHelmApp OR Custom app deploys
   c. NetworkPolicyBuilder creates isolation
5. Export results
```

## Design Patterns

### 1. Data-Driven Pattern

Most apps need no Python code - just YAML:

```yaml
- name: homarr
  category: public
  helm:
    chart: homarr
    repo: https://homarrlabs.github.io/homarr-charts
    version: 8.12.0
```

### 2. Single Model Pattern

`AppModel` is the single source of truth:
- Used by AppLoader for validation
- Used by AppRegistry for orchestration
- Used by GenericHelmApp for deployment
- Used by tests for discovery

### 3. Component Resource Pattern

`AppRegistry` is a Pulumi ComponentResource:
- Groups related resources
- Manages dependencies automatically
- Provides clear ownership

### 4. Template Method Pattern

`BaseApp.deploy()` defines the skeleton:
- Create namespace
- Call `deploy_components()` (subclass implementation)
- Create network policies

### 5. Strategy / Factory Pattern (Storage)

`StorageProvisionerFactory` dynamically selects the storage provider:
- `DefaultProvisioner`: Standard Kubernetes PVCs (OCI, local-path)
- `HetznerSMBProvisioner`: Specialized SMB mounts for Hetzner Storage Box, supporting isolated user-specific sub-accounts.

### 6. Manager Pattern (Hetzner Storage Box)

`StorageBoxManager` encapsulates multi-tenant storage logic:
- Automatically creates Hetzner sub-accounts for each user in `apps.yaml`
- Generates secure random passwords
- Provisions Kubernetes Secrets for the SMB CSI driver

### 5. Dependency Injection Pattern

Apps receive `AppModel` in constructor:
- Easy to test
- No global state
- Clear dependencies

## File Structure

```
src/
├── __main__.py
├── apps/
              # Entry point│   ├── base.py             # BaseApp, NetworkPolicyBuilder
│   ├── generic.py          # GenericHelmApp
│   ├── loader.py           # AppLoader
│   ├── impl/               # Custom implementations
│   │   └── kanidm.py
│   └── common/
│       ├── registry.py     # AppRegistry (secrets, storage, auth, routes)
│       ├── shared.py       # ServiceRegistry (Postgres, Redis)
│       └── builders.py     # K8s helpers (namespace, service, pvc, etc.)
├── utils/
│   └── schemas.py          # AppModel
└── tests/
    └── dynamic/            # Auto-discovery tests
```

## Categories

| Category | Description | Default Mode |
|----------|-------------|--------------|
| `public` | Exposed via Envoy Gateway | External |
| `protected` | Protected by Cloudflare Access | External |
| `internal` | No external exposure | ClusterIP |
| `database` | PostgreSQL/MySQL | ClusterIP |

## Testing

Tests automatically discover apps from `apps.yaml`:

- **Routing Tests**: Verify HTTP endpoints respond
- **Secrets Tests**: Verify ExternalSecrets sync
- **Network Tests**: Verify NetworkPolicies exist

No hardcoded lists - tests iterate over `apps_with_routing`, `apps_with_secrets`, etc.

## Benefits

1. **Less Code**: 90% of apps = just YAML
2. **Consistency**: Single model for all apps
3. **Correctness**: Topological sort prevents dependency issues
4. **Testability**: Auto-discovery tests
5. **Maintainability**: Separation of concerns

---

## How to Add a New App

### Option 1: Simple App (Recommended)

For most apps, just add an entry to `apps.yaml`:

```yaml
- name: myapp
  category: public          # public | protected | internal | database
  tier: standard           # critical | standard | ephemeral
  namespace: homelab       # Kubernetes namespace
  port: 8080               # Service port
  hostname: myapp.smadja.dev  # Optional: public hostname
  mode: public             # public | protected | internal
  clusters: [oci, local]   # Which clusters to deploy to
  dependencies:            # Namespaces this app can communicate with
    - external-secrets
    - envoy-gateway
    - kube-system
  helm:
    chart: myapp
    repo: https://charts.example.com
    version: 1.0.0
    # Optional: External values file
    values_file: ./apps/myapp-values.yaml

  # Optional: Let Helm handle the ingress/route instead of AppRegistry
  disable_auto_route: false

  storage:                 # Optional: persistent volumes
    - name: data
      size: 10Gi
      mount_path: /data
      # Optional features:
      # existing_claim: "my-shared-pvc" # Use an existing PVC instead of creating one
      # shared: true                    # Create ReadWriteMany PVC for multiple pod access

  secrets:                 # Optional: secrets from Doppler
    - name: myapp-creds
      keys: [api_key, api_secret]
  test:                    # Optional: test configuration
    routing: true
    expected_endpoints: [https://myapp.smadja.dev]

# Global Identities definition at the root of apps.yaml
identities:
  users:
    - name: "paul"
      display_name: "Paul Smadja"
      email: "paul@smadja.dev"
      groups: ["admins"]
  groups:
    - name: "admins"
      is_superuser: true
```

### Option 2: Custom App

For complex apps requiring custom Kubernetes resources, create a Python class:

1. **Create the app file** in `src/apps/impl/`:

```python
# src/apps/impl/myapp.py
from apps.base import BaseApp
from utils.schemas import AppModel

class MyApp(BaseApp):
    def __init__(self, model: AppModel):
        super().__init__(model)

    def deploy_components(self, provider, config):
        # Custom deployment logic
        return {"release": ...}
```

2. **Register in `__main__.py`**:

```python
if app_name == "myapp":
    from apps.impl.myapp import MyApp
    myapp = MyApp(app)
    myapp.deploy(provider, {})
```

### App Categories

| Category | When to Use | Default Dependencies |
|----------|-------------|---------------------|
| `public` | Exposed via Envoy Gateway | external-secrets, envoy-gateway, kube-system |
| `protected` | Behind Cloudflare Access | external-secrets, oauth2-proxy, kube-system |
| `internal` | Cluster-only access | kube-system |
| `database` | PostgreSQL/MySQL | kube-system |

### Shared Volumes (Storage)

Si plusieurs applications ont besoin d'accéder au même volume (par exemple un NAS NFS, MinIO S3, ou un PVC centralisé via Longhorn / SFTP) :

1. Déclarez une infrastructure de stockage commune (`nas-claim` par exemple).
2. Dans `apps.yaml`, référencez ce volume pour *plusieurs apps* en utilisant `existing_claim: nas-claim`.
3. Alternativement, passez `shared: true` lors de la création d'un volume pour générer un `ReadWriteMany` PVC.

### Dependencies

Always declare dependencies correctly - they are used for:
- **Deployment order**: Apps deploy after their dependencies
- **Network policies**: Only declared namespaces can communicate

```yaml
# Example: navidrome needs database
dependencies:
  - cnpg-system      # Database
  - external-secrets # Secrets
  - kube-system      # DNS
```

### Testing

Tests auto-discover apps from `apps.yaml`. After adding an app:

```bash
# Run routing tests
pytest tests/dynamic/test_routing_auto.py -v

# Run secrets tests
pytest tests/dynamic/test_secrets_auto.py -v

# Run network tests
pytest tests/dynamic/test_network_auto.py -v
```
