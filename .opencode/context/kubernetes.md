<!-- Context: kubernetes | Priority: high | Version: 1.0 | Updated: 2026-02-21 -->

# Kubernetes, GitOps, & KCL

## Core Concepts
- Everything in Kubernetes is managed by **Flux** (GitOps). Manual `kubectl apply` should only be used for debugging or bootstrapping; configurations must be persisted in git.
- **KCL** is used as the configuration language over plain YAML/Helm to ensure typesafety and reusability.

## Directory Structure (`/kubernetes`)
```
kubernetes/
├── bootstrap/           # Initial setup manifests (Flux, ESO)
├── clusters/            # Cluster-specific definitions (e.g., oci)
├── apps/                # The actual workloads, grouped by tenant
│   ├── infra/          # Core infrastructure (Authentik, traefik, databases)
│   ├── o11y/           # Observability (Prometheus, Grafana, Loki)
│   ├── public/         # Services accessible directly (Homepage, etc.)
│   └── automation/     # Internal tools (n8n)
└── konfig/              # KCL libraries and shared schemas
```

## Adding a New Application
1. **Define the App**: Create `apps/{tenant}/{app}/base/main.k` defining the `namespaceManifest`, `helmRelease`, and any needed `externalSecret` configurations (referencing Doppler).
2. **Kustomize**: Ensure the base is tracked in the tenant's `kustomization.yaml`.
3. **Commit & Push**: Flux will detect the git change and automatically reconcile the state in the target cluster.

## Common Operations
- Check GitOps sync: `flux get all --all-namespaces`
- Force sync: `flux reconcile source git homelab`
- View secrets synced by ESO: `kubectl get externalsecrets --all-namespaces`
