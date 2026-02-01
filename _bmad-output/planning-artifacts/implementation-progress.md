---
date: 2026-01-30
project: homelab
status: in-progress
lastUpdated: 2026-01-30
sourceOfTruth: epics-and-stories-homelab.md (v1.1 — 23 epics, 70 stories)
---

# Implementation Progress

Suivi d’implémentation aligné sur [Epics & Stories](epics-and-stories-homelab.md) (PRD v2.0, Architecture v4.0).

## Summary

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 0: Pre-Implementation | ✅ Complete | 100% |
| Phase 1: Foundation | 🟡 In Progress | 50% |
| Phase 2: Core Infrastructure | 🟡 In Progress | 60% |
| Phase 3: PROD + Oracle Cloud | 🔴 Blocked (OCI capacity) | 25% |
| Phase 4: Services MVP | ⬜ Not Started | 0% |
| Phase 5: Optional Services | ⬜ Not Started | 0% |
| Phase 6: Gaming | ⬜ Not Started | 0% |

---

## Phase 0: Pre-Implementation ✅

| Item | Status | Details |
|------|--------|---------|
| Domain Name | ✅ | `smadja.dev` via Cloudflare |
| Cloudflare Account | ✅ | Zone configurée |
| Oracle Cloud Account | ✅ | Region: `eu-paris-1` |
| GitHub Repository | ✅ | Repo actif |
| Local Tools | ✅ | kubectl, terraform, talosctl, argocd, etc. |
| Proxmox Installed | ✅ | IP: `192.168.68.51` |
| SSH Keys | ✅ | OCI + Proxmox |

---

## Phase 1: Foundation 🟡

### Epic 1.1: Proxmox Hypervisor Setup

| Story | Status | Notes |
|-------|--------|-------|
| 1.1.1 Install Proxmox VE | ✅ | Installé à 192.168.68.51 |
| 1.1.2 Configure ZFS Storage | ✅ | **Implémenté** : 2×14 To en miroir. Scripts : `scripts/proxmox/setup-zfs-14tb-only.sh`, `setup-nvme-cache.sh`. Guide : [docs/proxmox-setup-guide.md](../../docs/proxmox-setup-guide.md), [docs/proxmox-zfs-storage.md](../../docs/proxmox-zfs-storage.md) |
| 1.1.3 Configure GPU Passthrough | ⏳ | Pending |
| 1.1.4 Setup Terraform Provider | ✅ | **bpg/proxmox** dans `terraform/proxmox/`. Voir [docs/proxmox-terraform-best-practices.md](../../docs/proxmox-terraform-best-practices.md), [docs/proxmox-api-token.md](../../docs/proxmox-api-token.md) |

### Epic 1.2: Talos Linux DEV Cluster

| Story | Status | Notes |
|-------|--------|-------|
| 1.2.1 Create Talos VM via Terraform | ✅ | **talos-vms.tf** : talos-dev (2 vCPU, 4 GB, 50 GB). Premier boot : attacher ISO Talos en CDROM puis `talosctl apply-config`. Voir [docs/proxmox-talos-setup-verification.md](../../docs/proxmox-talos-setup-verification.md) |
| 1.2.2 Bootstrap DEV Cluster | ⏳ | Après ZFS + boot VM : `talosctl apply-config`, bootstrap. Config Talos : `talos/` |
| 1.2.3 Configure Talos Machine Config | 🟢 Ready | Configs dans `talos/` (controlplane.yaml, worker.yaml). Omni ClusterTemplate à faire après 1.3 |

### Epic 1.3: Omni Cluster Management

| Story | Status | Notes |
|-------|--------|-------|
| 1.3.1 Provision OCI Management VM | ✅ | **Terraform prêt** : `terraform/oracle-cloud/` — VM 1 OCPU, 6 GB, 50 GB, Ubuntu 24.04, Docker (cloud-init), IP publique réservée, SSH par clé. Bloqué en apply par capacité ARM OCI ; relancer `terraform apply` ou `scripts/oci-capacity-retry.sh`. Voir [docs/oci-management-vm.md](../../docs/oci-management-vm.md) |
| 1.3.2 Deploy Omni Server | 🟢 Ready | Squelette : `docker/oci-mgmt/` (docker-compose Omni + PostgreSQL). À déployer sur la VM OCI après 1.3.1. Voir [docker/oci-mgmt/README.md](../../docker/oci-mgmt/README.md) |
| 1.3.3 Register DEV Cluster with Omni | ⏳ | Dépend de 1.3.2 |
| 1.3.4 Configure MachineClasses | ⏳ | Dépend de Omni — `omni/machine-classes/` |

### Epic 1.4: ArgoCD GitOps Setup

| Story | Status | Notes |
|-------|--------|-------|
| 1.4.1 Install ArgoCD on DEV Cluster | 🟢 Ready | Manifests dans `kubernetes/argocd/` (install.yaml, app-of-apps.yaml) |
| 1.4.2 Configure Repository Connection | ⏳ | À faire au bootstrap (deploy key / token) |
| 1.4.3 Create Root Application | ✅ | App-of-apps dans `kubernetes/argocd/app-of-apps.yaml` |
| 1.4.4 Configure Sync Waves | 🟢 Ready | Applications avec annotations wave (infra, monitoring, apps) |
| 1.4.5 Create ApplicationSets | 🟢 Ready | Structure `kubernetes/infrastructure/`, `kubernetes/monitoring/`, `kubernetes/apps/` |

### Epic 1.5: Cilium CNI

| Story | Status | Notes |
|-------|--------|-------|
| 1.5.1 Deploy Cilium on DEV Cluster | ⏳ | À déployer via ArgoCD (Wave 0) — pas encore de chart dédié dans le repo |
| 1.5.2 Configure Gateway API | ⏳ | Après Cilium |

---

## Phase 2: Core Infrastructure 🟡

### Epic 2.1: Storage Infrastructure

| Story | Status | Notes |
|-------|--------|-------|
| 2.1.1 Deploy local-path Provisioner | ⏳ | Après cluster DEV opérationnel |
| 2.1.2 Configure NFS Storage Class | ⏳ | NFS sur Proxmox/ZFS — voir Phase 1.1.2 |

### Epic 2.2: Certificate Management

| Item | Status | Notes |
|------|--------|-------|
| cert-manager | ✅ | ArgoCD Application dans `kubernetes/infrastructure/cert-manager/` |
| ClusterIssuers (Let's Encrypt + Cloudflare) | 🟢 Ready | À configurer après déploiement (secret Cloudflare) |

### Epic 2.3: External DNS & Secrets

| Item | Status | Notes |
|------|--------|-------|
| SOPS + Age | ✅ | `.sops.yaml`, secrets chiffrés (ex. Cloudflare) |
| External Secrets Operator | ⏳ | Pas encore de manifest dédié |
| external-dns | ⏳ | À ajouter (Wave 2) |
| Bitwarden SecretStore | ⏳ | Après ESO |

### Epic 2.4: Monitoring Stack

| Item | Status | Notes |
|------|--------|-------|
| Prometheus | ✅ | `kubernetes/monitoring/prometheus/` |
| Grafana | ✅ | `kubernetes/monitoring/grafana/` |
| Loki | ✅ | `kubernetes/monitoring/loki/` |
| Alertmanager | ✅ | Config + Discord webhook dans `kubernetes/monitoring/alertmanager/` |
| Alert Rules | ✅ | Node, K8s, Apps, Certs |
| Alloy (Grafana Agent) | ⏳ | Non déployé |
| ntfy | ⏳ | Non déployé |

### Epic 2.5: AdGuard Home DNS

| Item | Status | Notes |
|------|--------|-------|
| AdGuard Home | ⏳ | À déployer sur cluster PROD (Phase 3) |

---

## Phase 3: PROD + Oracle Cloud 🔴

### Epic 3.1: PROD Cluster Deployment

| Story | Status | Notes |
|-------|--------|-------|
| 3.1.1 Provision PROD VMs via Terraform | ✅ | **talos-vms.tf** : talos-prod-cp, talos-prod-worker-1 (16 GB total) |
| 3.1.2 Bootstrap PROD Cluster | ⏳ | Après DEV stable + ZFS |
| 3.1.3 Deploy Longhorn Storage | 🟢 Ready | Application Velero/Longhorn prête — déploiement après PROD |

### Epic 3.2: Oracle Cloud Kubernetes Cluster

| Item | Status | Notes |
|------|--------|-------|
| OCI Terraform (réseau, stockage, budget) | ✅ | `terraform/oracle-cloud/` — VCN, subnets, Object Storage (Velero), budget |
| Compute Instances (management + 2 nœuds K8s) | 🔴 | **Blocked** : "Out of host capacity" (ARM). Retry : `scripts/oci-capacity-retry.sh` ou `terraform apply` périodique |

### Epic 3.3: Identity & Access

| Item | Status | Notes |
|------|--------|-------|
| Keycloak | ✅ | ArgoCD Application + realm dans `kubernetes/apps/keycloak/` |
| oauth2-proxy | ⏳ | À déployer avec Keycloak (Tier 1) |
| Keycloak Clients (OIDC) | 🟢 Ready | Realm `homelab` — à finaliser après déploiement |

### Epic 3.4: Cloudflare Tunnel & Zero Trust

| Item | Status | Notes |
|------|--------|-------|
| Tunnel Terraform | ✅ | `terraform/cloudflare/tunnel.tf` |
| Cloudflared K8s | ✅ | `kubernetes/infrastructure/cloudflared/` |
| Twingate Connector | ✅ | `kubernetes/infrastructure/twingate/` |
| Access Policies | ✅ | Internal services protected |

### Epic 3.5: CI/CD Pipeline

| Item | Status | Notes |
|------|--------|-------|
| terraform-oci.yml | ✅ | Plan + Apply |
| terraform-cloudflare.yml | ✅ | Plan + Apply |
| terraform-ovhcloud.yml | ✅ | Plan + Apply |
| security.yml | ✅ | Gitleaks, Trivy, tfsec, Kubescape |
| Pre-commit hooks | ✅ | `.pre-commit-config.yaml` |

---

## Phase 4: Services MVP ⬜

| Epic | Status | Notes |
|------|--------|-------|
| 4.1 Critical Services (Nextcloud, Vaultwarden, Baïkal) | ⬜ | Dépend de Phase 3 (CLOUD cluster, Keycloak, Twingate) |
| 4.2 Media (Comet, Navidrome, Lidarr) | ⬜ | Idem |
| 4.3 Home (Home Assistant, Audiobookshelf, Komga, Romm) | ⬜ | Cluster PROD |
| 4.4 Dashboard (Glance) | ⬜ | CLOUD |
| 4.5 Backup (Velero, Volsync/Restic, ZFS snapshots) | 🟢 Ready | Manifests Velero prêts ; Volsync/ZFS à configurer |

---

## Phase 5: Optional Services ⬜

| Epic | Status | Notes |
|------|--------|-------|
| 5.1 Optional (Immich, n8n, Mealie, Invidious) | ⬜ | Après Phase 4 stable |

---

## Phase 6: Gaming & Advanced ⬜

| Epic | Status | Notes |
|------|--------|-------|
| 6.1 Windows Gaming VM (GPU passthrough, Parsec/Moonlight) | ⏳ | Dépend de 1.1.3 (GPU passthrough) |
| 6.2 KubeVirt (future) | ⬜ | Optionnel |

---

## Infrastructure Created

### Terraform

| Module | Location | Status |
|--------|----------|--------|
| Oracle Cloud | `terraform/oracle-cloud/` | ✅ Applied (réseau, bucket, budget — VMs en attente capacité ARM) |
| Cloudflare | `terraform/cloudflare/` | ✅ Applied |
| OVHcloud | `terraform/ovhcloud/` | ✅ Applied (Object Storage Paris) |
| Proxmox | `terraform/proxmox/` | ✅ Prêt (bpg/proxmox, talos-vms.tf) |

### Kubernetes Manifests

| Category | Location | Applications |
|----------|----------|--------------|
| ArgoCD | `kubernetes/argocd/` | App-of-apps, install, values |
| Infrastructure | `kubernetes/infrastructure/` | cert-manager, cloudflared, twingate, reloader, velero, network-policies |
| Monitoring | `kubernetes/monitoring/` | prometheus, grafana, loki, alertmanager |
| Apps | `kubernetes/apps/` | homepage, keycloak, uptime-kuma, fider, docusaurus |

### Security & Tooling

| Tool | Purpose | Status |
|------|---------|--------|
| SOPS + Age | Chiffrement secrets | ✅ |
| Gitleaks | Détection secrets | ✅ |
| Trivy | SAST | ✅ |
| tfsec | Terraform security | ✅ |
| Kubescape | K8s security | ✅ |
| Pre-commit | Hooks locaux | ✅ |

### Documentation

| Document | Location |
|----------|----------|
| Bootstrap | `docs/BOOTSTRAP.md` |
| Architecture | `docs/architecture-diagram.md` |
| Cloudflare | `docs/cloudflare-free-tier.md` |
| Oracle | `docs/oracle-free-tier-limits.md` |
| Keycloak SSO | `docs/keycloak-sso.md` |
| Twingate | `docs/twingate-setup.md` |
| Velero | `docs/velero-backup-restore.md` |
| User Services | `docs/user-services.md` |
| OCI CI/CD | `docs/setup-oci-cicd.md` |
| Proxmox Terraform | `docs/proxmox-terraform-best-practices.md`, `docs/proxmox-api-token.md` |
| Proxmox ZFS | `docs/proxmox-zfs-storage.md` |
| Proxmox Setup | `docs/proxmox-setup-guide.md` |
| Proxmox + Talos | `docs/proxmox-talos-setup-verification.md` |
| OVHcloud | `docs/setup-ovh-cloud.md` |
| Secrets | `secrets/README.md` |

---

## Blocking Issues

### 1. Oracle Cloud ARM Capacity
- **Status**: 🔴 Blocked
- **Impact**: VMs management + 2 nœuds K8s non créées
- **Mitigation**: `scripts/oci-capacity-retry.sh` ou `terraform apply` périodique
- **ETA**: Inconnu (dépend Oracle)

### 2. ~~Proxmox Storage~~
- **Status**: ✅ Disques reçus — **2×14 To** (miroir) ; **2×2 To** optionnels ; NVMe cache : `scripts/proxmox/setup-nvme-cache.sh`
- **Next**: Exécuter ZFS (ex. `scripts/proxmox/setup-zfs-14tb-only.sh`) puis cache NVMe si besoin.

---

## Next Steps (Priority)

1. **Proxmox — ZFS** : Configurer le pool (2×14 To) avec les scripts existants.
2. **Oracle — VMs** : Relancer `terraform apply` quand capacité ARM disponible.
3. **DEV cluster** : Boot Talos sur la VM DEV (1.2.2), puis installer ArgoCD (1.4.1).
4. **Omni** : Dès OCI VM créée — déployer Omni, enregistrer DEV (1.3.x).
5. **PROD cluster** : Bootstrap PROD (3.1.2), puis services Phase 4.

---

*Dernière mise à jour : 2026-01-30 — Aligné avec epics-and-stories-homelab.md v1.1 (23 epics, 70 stories).*
