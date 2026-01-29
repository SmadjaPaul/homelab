# Homelab Infrastructure

GitOps-driven Infrastructure as Code for a hybrid homelab running on **Proxmox VE** with **Talos Linux** Kubernetes clusters managed by **Omni** (self-hosted on Oracle Cloud), featuring Dev/Prod environments and CI/CD pipeline.

## Architecture Overview

```
                    ┌─────────────────────────────────────┐
                    │      OMNI (Self-Hosted on OCI)      │
                    │  Single pane of glass for clusters  │
                    │  + Keycloak SSO + Cloudflare Tunnel │
                    └─────────────────────────────────────┘
                                        │
           ┌────────────────────────────┼────────────────────────────┐
           │                            │                            │
           ▼                            ▼                            ▼
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   DEV Cluster       │    │   PROD Cluster      │    │   CLOUD Cluster     │
│   (Proxmox)         │    │   (Proxmox)         │    │   (Oracle Cloud)    │
│   ────────────────  │    │   ────────────────  │    │   ────────────────  │
│   • Minimal testing │    │   • Stable services │    │   • Family services │
│   • 4GB RAM         │    │   • Gaming VMs      │    │   • Comet (critical)│
│   • Can be stopped  │    │   • 16GB RAM        │    │   • 19GB RAM        │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## Tech Stack

| Layer | Technology | Source |
|-------|------------|--------|
| **Hypervisor** | Proxmox VE | [ravilushqa/homelab](https://github.com/ravilushqa/homelab) |
| **OS** | Talos Linux | [All reference repos] |
| **Cluster Management** | Omni (self-hosted on OCI) | [qjoly/GitOps](https://github.com/qjoly/GitOps) |
| **GitOps** | ArgoCD + Sync Waves | [mitchross/talos-argocd-proxmox](https://github.com/mitchross/talos-argocd-proxmox) |
| **CNI** | Cilium (eBPF) | [All reference repos] |
| **SSO/Identity** | Keycloak | - |
| **Zero Trust** | Twingate + Cloudflare Tunnel | [Mafyuh/iac](https://github.com/Mafyuh/iac) |
| **Secrets** | External Secrets + Bitwarden | [Mafyuh/iac](https://github.com/Mafyuh/iac) |
| **Security** | Wazuh SIEM, Trivy, oauth2-proxy | [Mafyuh/iac](https://github.com/Mafyuh/iac) |
| **IaC** | Terraform, Ansible | [ravilushqa/homelab](https://github.com/ravilushqa/homelab) |
| **Updates** | Renovate | [ahinko/home-ops](https://github.com/ahinko/home-ops) |

## Key Features

- **Dev/Prod Separation**: CI deploys to DEV first, promote to PROD after validation
- **Omni on Oracle Cloud**: Free hosting, accessible anywhere, Keycloak SSO
- **Zero Trust**: Cloudflare Tunnel + Twingate (no open ports)
- **Comet Critical**: Static IP on Oracle Cloud for Real-Debrid stability
- **Minimal DEV**: 4GB RAM, can be shut down when not testing
- **Security Stack**: Keycloak SSO, Wazuh SIEM, Trivy scanning

## Hardware

**Homelab Server** (Proxmox Host):
- **URL**: https://192.168.68.51:8006
- **RAM**: 64GB
- **Storage**: 1TB SSD + 2x 20TB HDD
- **GPU**: NVIDIA (for gaming VMs)

**Oracle Cloud** (Always Free - 24GB RAM, 4 OCPUs):
- **oci-mgmt**: Omni + Keycloak + Cloudflare (5GB, 1 OCPU)
- **oci-node-1/2**: Kubernetes cluster (19GB, 3 OCPUs)

## Services

### Oracle Cloud (Family Shared)

| Category | Services |
|----------|----------|
| **Management** | Omni, Keycloak SSO, Cloudflare Tunnel |
| **Media** | Comet ⚠️, Navidrome, Lidarr |
| **Critical** | Vaultwarden, Baïkal, Twingate |
| **Collaborative** | Nextcloud |
| **Dashboard** | Glance (family homepage) |
| **Optional (Phase 2)** | Immich, n8n, Mealie, Invidious |

> ⚠️ **Comet**: Requires static IP for Real-Debrid (Oracle Cloud = perfect fit)

### Homelab (Local)

| Category | Services |
|----------|----------|
| **Home** | AdGuard Home, Home Assistant |
| **Media** | Audiobookshelf, Komga, Romm |
| **Monitoring** | Prometheus, Grafana, Loki, ntfy |
| **Gaming** | Windows VM (32GB, GPU passthrough) |

## Repository Structure

```
homelab/
├── terraform/              # Infrastructure as Code
│   ├── proxmox/            # Proxmox VM definitions
│   └── oracle-cloud/       # OCI resources
├── docker/                 # Docker Compose for management VM
│   └── oci-mgmt/           # Omni + Keycloak + Cloudflare
├── omni/                   # Omni cluster templates
│   ├── clusters/           # Cluster definitions
│   └── machine-classes/    # Node profiles
├── kubernetes/             # Kubernetes manifests
│   ├── base/               # Shared base manifests
│   │   ├── infrastructure/ # Cilium, cert-manager, etc.
│   │   ├── security/       # oauth2-proxy, Twingate, Wazuh
│   │   ├── monitoring/     # Prometheus, Grafana, Loki
│   │   └── apps/           # Media, Home, Collaborative
│   ├── overlays/           # Environment patches
│   │   ├── dev/            # Minimal resources
│   │   ├── prod/           # Full resources
│   │   └── cloud/          # Oracle Cloud specific
│   └── clusters/           # Per-cluster configs
├── ansible/                # Configuration management
├── scripts/                # Utility scripts
└── docs/                   # Documentation
```

## Quick Start

### Prerequisites

```bash
# Install required tools
brew install terraform ansible kubectl talosctl helm argocd
```

### 1. Provision Oracle Cloud Management VM

```bash
cd terraform/oracle-cloud
terraform init && terraform apply

# Setup Omni + Keycloak via Docker Compose
ssh oci-mgmt
docker compose up -d
```

### 2. Provision Proxmox VMs

```bash
cd terraform/proxmox
terraform init && terraform apply
```

### 3. Register Nodes with Omni

```bash
# Sync cluster templates
omnictl cluster template sync -f omni/clusters/prod.yaml
omnictl kubeconfig --cluster prod
```

### 4. Bootstrap ArgoCD

```bash
kubectl apply -k kubernetes/base/argocd
kubectl apply -f kubernetes/base/argocd/root.yaml
```

## CI/CD Workflow

```
Git Push → CI Validation → Deploy DEV → Stability Check → Promote PROD
                              ↓
                        Renovate PRs
                        (auto-merge minor/patch)
```

## Documentation

- [Architecture Document](_bmad-output/planning-artifacts/architecture-proxmox-omni.md)
- [Installation Guide](docs/installation.md) *(coming soon)*

## Inspirations

| Repo | What We Adopted |
|------|-----------------|
| [qjoly/GitOps](https://github.com/qjoly/GitOps) | Omni templates, Cloudflare Tunnels |
| [ravilushqa/homelab](https://github.com/ravilushqa/homelab) | Proxmox + Terraform |
| [mitchross/talos-argocd-proxmox](https://github.com/mitchross/talos-argocd-proxmox) | ArgoCD sync waves |
| [Mafyuh/iac](https://github.com/Mafyuh/iac) | Twingate, Wazuh, n8n, security stack |
| [ahinko/home-ops](https://github.com/ahinko/home-ops) | Renovate, Taskfile patterns |

## Status

**Current Phase**: Infrastructure Setup

- [x] Proxmox installed (192.168.68.51)
- [ ] Terraform Proxmox provider configured
- [ ] Oracle Cloud management VM (Omni + Keycloak)
- [ ] PROD cluster bootstrap
- [ ] DEV cluster (minimal)
- [ ] Oracle Cloud K8s cluster
- [ ] ArgoCD deployment
- [ ] Core services

---

**BMad Method Project** - See `.cursorrules` for workflow commands
