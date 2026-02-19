# Agent Instructions

## Overview
Multi-cluster Kubernetes homelab managed through GitOps using Flux, with Doppler for secrets management and GitHub Actions for CI/CD.

**Key Architecture:**
- **Kubernetes**: OCI (Oracle Cloud Infrastructure) with OKE
- **GitOps**: Flux for declarative Kubernetes configuration
- **Secrets**: Doppler (synced via External Secrets Operator)
- **CI/CD**: GitHub Actions
- **Config**: Kustomize with Helm
- **Networking**: Cloudflare (free tier) with Cloudflare Tunnel
- **Authentication**: Authentik as IDP with Cloudflare Access for RBAC

## Current Status
- **Finalizing deployment** - Getting ready for production
- **Setting up Authentik** - Identity provider for all services
- **Configuring Cloudflare Access** - Zero-trust access with RBAC

## Directory Structure
```
.
├── kubernetes/           # Kubernetes configurations
│   ├── apps/            # Application manifests (by category)
│   │   ├── automation/  # n8n, automation tools
│   │   ├── infra/       # traefik, authentik, aiven-operator
│   │   └── public/      # Public-facing apps
│   ├── bootstrap/       # Cluster bootstrap (Flux, RBAC)
│   └── clusters/       # OCI cluster configs
├── .github/workflows/  # GitHub Actions CI/CD
├── scripts/            # Utility scripts
├── docs/              # Documentation
└── terraform/         # Terraform IaC (OCI, Cloudflare, Authentik infra)
```

## Secrets Management
**IMPORTANT**: All secrets are stored in **Doppler**.

- Secrets synced via External Secrets Operator (managed by Flux)
- External Secrets Operator pulls secrets from Doppler and creates K8s secrets
- Flux manages the ExternalSecret resources in Kubernetes

## Networking Architecture
```
Internet → Cloudflare → Cloudflare Tunnel → Kubernetes Services
                    ↓
              Cloudflare Access (Authentik OAuth)
                    ↓
              Authentik (IDP)
```

## Infrastructure Boundaries
- **Terraform**: OCI infrastructure (compute, network, OKE) + Cloudflare + Authentik deployment
- **Kubernetes**: Container orchestration on OKE
- **Flux**: GitOps reconciliation for ALL Kubernetes resources
- **Doppler**: Secret storage (source of truth)
- **External Secrets Operator**: Syncs Doppler secrets to Kubernetes
- **Cloudflare**: DNS, Tunnel, Access (Zero-trust)
- **Authentik**: Identity Provider for SSO
- **GitHub Actions**: CI/CD pipelines

## Key Tools
- **kubectl**: Kubernetes management
- **flux**: GitOps CLI (manages ALL K8s resources)
- **doppler**: Secret storage and management
- **terraform**: IaC for cloud infrastructure (OCI, Cloudflare, Authentik)
- **task**: Task automation (see `task -l`)

## Development Workflow

### Deploying a New Application
1. Create namespace and HelmRelease in `kubernetes/apps/{category}/{app}/base/`
2. Add to category kustomization.yaml
3. Push to Git - Flux will auto-sync

### Managing Secrets
1. Secrets are stored in Doppler
2. Flux manages ExternalSecret resources in K8s
3. External Secrets Operator syncs secrets from Doppler to K8s

### Access Control (Authentik + Cloudflare Access)
1. Configure application in Authentik
2. Create Access Policy in Cloudflare
3. Map groups to RBAC policies

### CI/CD Pipeline
- `.github/workflows/deploy.yml`: Deploys to OKE on push to main
- `.github/workflows/flux-diff.yaml`: Shows Flux diff before deploy
- `.github/workflows/terraform.yml`: OCI infrastructure
- `.github/workflows/lint.yaml`: YAML linting

### Common Commands
```bash
# Check Flux status
flux get all --all-namespaces

# Sync Flux
flux reconcile source git homelab

# Check External Secrets
kubectl get externalsecrets --all-namespaces

# Validate Kustomize
kubectl kustomize kubernetes/apps/myapp
```
