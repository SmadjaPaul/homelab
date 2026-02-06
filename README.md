# Homelab Infrastructure

Personal homelab running on Proxmox VE with Kubernetes (Talos Linux via Omni), managed via GitOps.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                 │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                ┌─────────▼─────────┐
                │   Cloudflare      │
                │   (DNS, WAF,      │
                │    Tunnel)        │
                └─────────┬─────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
┌───────▼───────┐ ┌───────▼───────┐ ┌───────▼───────┐
│   Proxmox     │ │  Oracle Cloud │ │  Oracle Cloud │
│   (On-prem)   │ │  (ARM VMs)    │ │  (ARM VMs)    │
│               │ │  oci-mgmt     │ │  oci-node-1/2 │
└───────┬───────┘ └───────┬───────┘ └───────┬───────┘
        │                 │                 │
        └─────────────────┴─────────────────┘
                          │
                ┌─────────▼─────────┐
                │   Talos Linux     │
                │   (via Omni)      │
                │                   │
                │   ┌─────────────┐ │
                │   │ Kubernetes  │ │
                │   │  Cluster    │ │
                │   └─────────────┘ │
                └───────────────────┘
```

## Components

### Infrastructure
| Component | Purpose | Location |
|-----------|---------|----------|
| Proxmox VE | Hypervisor | On-premises |
| Oracle Cloud | ARM VMs (Free Tier) | eu-paris-1 |
| Cloudflare | DNS, WAF, Tunnel | Cloud |

### Kubernetes Stack
| Component | Purpose |
|-----------|---------|
| Talos Linux | Immutable K8s OS |
| Omni | Cluster management |
| ArgoCD | GitOps |
| Cilium | CNI |

### Applications
| App | URL | Description |
|-----|-----|-------------|
| Homepage | https://home.smadja.dev | Dashboard |
| Grafana | https://grafana.smadja.dev | Monitoring |
| ArgoCD | https://argocd.smadja.dev | GitOps |
| Authentik | https://auth.smadja.dev | SSO |

## Quick Start

### Prerequisites

```bash
# Install CLI tools
brew install terraform kubectl helm argocd talosctl

# Install OCI CLI
brew install oci-cli
```

### Deploy Infrastructure

```bash
# Oracle Cloud
cd terraform/oracle-cloud
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init && terraform apply

# Cloudflare
cd terraform/cloudflare
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your API token
terraform init && terraform apply
```

### Bootstrap Kubernetes

```bash
# After Talos cluster is ready via Omni:
kubectl apply -k kubernetes/argocd/
kubectl apply -f kubernetes/argocd/app-of-apps.yaml
```

## Directory Structure

```
homelab/
├── terraform/
│   ├── oracle-cloud/     # OCI infrastructure
│   └── cloudflare/       # DNS and security
├── kubernetes/
│   ├── argocd/           # ArgoCD bootstrap
│   ├── apps/             # User applications
│   ├── infrastructure/   # Cluster infrastructure
│   └── monitoring/       # Observability stack
├── docs-site/docs/       # Documentation (runbooks, architecture, décisions & limites)
└── scripts/              # Helper scripts
```

## Cost

**Total: $0/month** (Free tier only)

| Service | Tier | Limit |
|---------|------|-------|
| Oracle Cloud | Always Free | 4 OCPUs, 24GB RAM, 200GB storage |
| Cloudflare | Free | Unlimited DNS, CDN, Tunnel |
| GitHub | Free | Unlimited repos |

## Documentation

- **[docs-site/](docs-site/)** — Site Docusaurus : runbooks (incidents, rotation des clés), architecture, décisions & limites (state Terraform, CI/CD, free tiers). C’est la seule source de doc opérationnelle.
- **[_bmad-output/planning-artifacts/README.md](_bmad-output/planning-artifacts/README.md)** — Livrables BMad (PRD, architecture, epics).
- **Recréer les secrets** : [docs-site/docs/runbooks/rotate-secrets.md](docs-site/docs/runbooks/rotate-secrets.md). Liste et dépannage : [.github/DEPLOYMENTS.md](.github/DEPLOYMENTS.md).
- **🔧 Plan de stabilisation** : [.github/STABILIZATION-PLAN.md](.github/STABILIZATION-PLAN.md) — Problèmes bloquants et actions prioritaires.

## Secrets Management

Secrets are stored in:
- **GitHub Secrets** — CI/CD credentials (OCI session token, Cloudflare, etc.). See [Rotate secrets](docs-site/docs/runbooks/rotate-secrets.md) and [.github/DEPLOYMENTS.md](.github/DEPLOYMENTS.md).
- **OCI Vault** (optional) — Terraform-created vault for CI secrets. See [terraform/oracle-cloud/README.md](terraform/oracle-cloud/README.md#oci-vault-secrets-pour-la-ci--free-tier).
- **Kubernetes Secrets** — App secrets (SOPS + Age, or external-secrets later).

Never commit secrets to the repository!

## Links

- [Architecture & décisions / limites](docs-site/docs/advanced/architecture.md) — Vue d’ensemble et [Décisions et limites](docs-site/docs/advanced/decisions-and-limits.md) (free tiers OCI/Cloudflare, state Terraform, CI/CD).
