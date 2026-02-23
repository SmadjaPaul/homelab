# Agent Instructions

## Overview
Multi-cluster Kubernetes homelab managed through GitOps using Flux, with Doppler for secrets management and GitHub Actions for CI/CD.

**Key Architecture:**
- **Local Kubernetes**: Talos VMs on Proxmox (Aoostar WTR Max - 64GB RAM)
  - 3 nodes × (4 CPUs, 16GB RAM, 50GB disk)
  - Managed via `talosctl` (no Omni)
- **Cloud Kubernetes**: OCI OKE (2 × 12GB nodes)
- **GitOps**: Flux for declarative Kubernetes configuration
- **Secrets**: Doppler (synced via External Secrets Operator)
- **CI/CD**: GitHub Actions
- **Config**: Kustomize with Helm
- **Networking**: Cloudflare (free tier) with Cloudflare Tunnel
- **Storage**: ZFS on Proxmox (no TrueNAS VM)

## Current Status
- **Creating Talos VMs** - Terraform deployment in progress
- **Pending**: Bootstrap Talos cluster with talosctl
- **Pending**: Deploy Flux and connect clusters

## Directory Structure
```
.
├── kubernetes/           # Kubernetes configurations
│   ├── apps/            # Application manifests (by category)
│   │   ├── automation/  # n8n, automation tools
│   │   ├── infra/      # traefik, cert-manager, longhorn
│   │   └── public/     # Public-facing apps
│   ├── bootstrap/       # Cluster bootstrap (Flux, RBAC)
│   └── clusters/        # Cluster-specific configs
│       ├── local/       # Talos on Proxmox
│       └── oci/         # OKE on Oracle Cloud
├── terraform/
│   ├── proxmox/        # Proxmox VMs (Talos)
│   └── oci/            # OCI infrastructure (OKE)
├── .github/workflows/  # GitHub Actions CI/CD
└── scripts/            # Utility scripts
```
.
├── kubernetes/           # Kubernetes configurations
│   ├── apps/            # Application manifests (by category)
│   │   ├── automation/  # n8n, automation tools
│   │   ├── infra/       # traefik, aiven-operator
│   │   └── public/      # Public-facing apps
│   ├── bootstrap/       # Cluster bootstrap (Flux, RBAC)
│   └── clusters/       # OCI cluster configs
├── .github/workflows/  # GitHub Actions CI/CD
├── scripts/            # Utility scripts
├── docs/              # Documentation
└── terraform/         # Terraform IaC (OCI, Cloudflare, Auth0 infra)
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
              Cloudflare Access (Auth0 OAuth)
                    ↓
              Auth0 (IDP)
```

## Infrastructure Boundaries
- **Terraform**: OCI infrastructure (compute, network, OKE) + Cloudflare
- **Kubernetes**: Container orchestration on OKE
- **Flux**: GitOps reconciliation for ALL Kubernetes resources
- **Doppler**: Secret storage (source of truth)
- **External Secrets Operator**: Syncs Doppler secrets to Kubernetes
- **Cloudflare**: DNS, Tunnel, Access (Zero-trust)
- **GitHub Actions**: CI/CD pipelines

## Key Tools
- **kubectl**: Kubernetes management
- **flux**: GitOps CLI (manages ALL K8s resources)
- **doppler**: Secret storage and management
- **terraform**: IaC for cloud infrastructure (OCI, Cloudflare, Auth0)
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

### Access Control (Auth0 + Cloudflare Access)
1. Configure application in Auth0
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
