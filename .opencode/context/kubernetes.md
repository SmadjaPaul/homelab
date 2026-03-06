<!-- Context: kubernetes | Priority: high | Version: 1.1 | Updated: 2026-03-06 -->

# Kubernetes & Pulumi (IaC)

## Core Concepts
- The entire Kubernetes deployment is managed by **Pulumi (Python)**. Manual `kubectl apply` should only be used for debugging.
- **Data-Driven Configuration**: The single source of truth for workloads is `kubernetes-pulumi/apps.yaml`. Python code is strictly used for infrastructure scaffolding, registries, and dynamic resource generation.

## Directory Structure (`/kubernetes-pulumi`)
```
kubernetes-pulumi/
├── apps.yaml            # Single source of truth (apps, buckets, identities)
├── k8s-core/            # Phase 1: Namespaces, CRDs, Operators
├── k8s-storage/         # Phase 2: Storage, Databases, S3
├── k8s-apps/            # Phase 3: Applications & Authentik SSO
└── shared/              # Reusable logic (BaseApp, Helm Adapters, Registries)
```

## Adding a New Application
1. **Define the App**: Simply add a block to `apps.yaml` containing the `name`, `helm` chart info, `secrets`, and `storage`.
2. **Commit & Deploy**: Apply changes via Pulumi in the `k8s-apps` stack.
3. No custom Python is needed unless the app requires highly specific (non-Helm) Kubernetes resources.

## Common Operations
- Preview changes: `pulumi preview`
- Apply changes: `pulumi up`
- Secret generation is handled automatically via Doppler and External Secrets Operator (ESO).
