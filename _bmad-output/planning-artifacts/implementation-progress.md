---
date: 2026-01-30
project: homelab
status: in-progress
lastUpdated: 2026-02-10
sourceOfTruth: epics-and-stories-homelab.md (25 epics, 84 stories — Phase 4b Stack IA & Services entreprise)
---

# Implementation Progress

Suivi d’implémentation aligné sur [Epics & Stories](epics-and-stories-homelab.md) (PRD v2.0, Architecture v6.0). Intégration Stack IA et services entreprise : [stack-ia-et-services-entrepreneuse.md](stack-ia-et-services-entrepreneuse.md).

## Summary

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 0: Pre-Implementation | ✅ Complete | 100% |
| Phase 1: Foundation | 🟡 In Progress | 50% |
| Phase 2: Core Infrastructure | 🟡 In Progress | 60% |
| Phase 3: PROD + Oracle Cloud | 🟡 In Progress | 25% |
| Phase 4: Services MVP | ⬜ Not Started | 0% |
| **Phase 4b: Stack IA & Services entreprise** | **⬜ Not Started** | **0%** |
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
| 1.1.2 Configure ZFS Storage | ✅ | **Implémenté** : 2×14 To en miroir. Scripts : `scripts/proxmox/setup-zfs-14tb-only.sh`, `setup-nvme-cache.sh`. |
| 1.1.3 Configure GPU Passthrough | ⏳ | **Backlog (low priority)** - À traiter en dernier. Script préparé : `scripts/proxmox/configure-gpu-passthrough.sh` |
| 1.1.4 Setup Terraform Provider | ✅ | **bpg/proxmox** dans `terraform/proxmox/`. Voir `terraform/proxmox/README.md`. |

### Epic 1.2: Talos Linux DEV Cluster

| Story | Status | Notes |
|-------|--------|-------|
| 1.2.1 Create Talos VM via Terraform | ✅ | **talos-vms.tf** : talos-dev (2 vCPU, 4 GB, 50 GB). Premier boot : attacher ISO Talos en CDROM puis `talosctl apply-config`. Voir `terraform/proxmox/README.md`. |
| 1.2.2 Bootstrap DEV Cluster | ⏳ | Après ZFS + boot VM : `talosctl apply-config`, bootstrap. Config Talos : `talos/` |
| 1.2.3 Configure Talos Machine Config | 🟢 Ready | Configs dans `talos/` (controlplane.yaml, worker.yaml). Omni ClusterTemplate à faire après 1.3 |

### Epic 1.3: Omni Cluster Management

| Story | Status | Notes |
|-------|--------|-------|
| 1.3.1 Provision OCI Management VM | ✅ | **Terraform** : `terraform/oracle-cloud/` — VM oci-mgmt (1 OCPU, 6 GB). Apply via CI (`task oci:terraform:apply`) ou local. Voir `terraform/oracle-cloud/README.md`. |
| 1.3.2 Deploy Omni Server | ✅ | **Déployé via CI** : workflow `.github/workflows/deploy-oci-mgmt.yml`. Stack : Omni, PostgreSQL, Authentik, Cloudflared. Voir [docker/oci-mgmt/README.md](../../docker/oci-mgmt/README.md). |
| 1.3.3 Register DEV Cluster with Omni | 🟡 In Progress | **CLOUD** : image Omni (créer cluster dans UI, télécharger image Oracle, import OCI, `talos_image_id`). **DEV** : config Omni dans talos/*.yaml + talosctl apply-config. Docs : `docs-site/docs/infrastructure/kubernetes.md`. |
| 1.3.4 Configure MachineClasses | 🟢 Ready | **Story** : `1-3-4-configure-machineclasses.md`. Specs dans `omni/machine-classes/README.md` (control-plane, worker, gpu-worker). Création des classes dans l’UI Omni ou via API. |

### Epic 1.4: ArgoCD GitOps Setup

| Story | Status | Notes |
|-------|--------|-------|
| 1.4.1 Install ArgoCD on DEV Cluster | 🟡 Ready | **Ansible playbook créé** : `ansible/playbooks/install-argocd.yml`, rôle `ansible/roles/argocd_install/`. Manifests dans `kubernetes/argocd/` (install.yaml, app-of-apps.yaml). Prêt pour installation. |
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

| Story | Status | Notes |
|-------|--------|-------|
| 3.2.1 Provision OCI Compute via Terraform | 🟢 Ready | **Terraform** : `compute.tf` (oci-node-1 : 2 OCPU, 12 GB, 64 GB ; oci-node-2 : 1 OCPU, 6 GB, 75 GB). Outputs `k8s_nodes` (VNIC public IP). Apply via CI ou `task oci:terraform:apply`. Story : `3-2-1-provision-oci-compute-via-terraform.md`. |
| 3.2.2 Bootstrap CLOUD Cluster | 🟢 Ready | **Talos** : `talos/controlplane-cloud.yaml`, `talos/worker-cloud.yaml` (OCI 10.0.1.x, Omni). Story : `3-2-2-bootstrap-cloud-cluster.md`. Bootstrap manuel puis enregistrement Omni (1.3.3). |

### Epic 3.3: Identity & Access

| Item | Status | Notes |
|------|--------|-------|
| Authentik | ✅ | ArgoCD Application dans `kubernetes/apps/authentik/` ; config Terraform `terraform/authentik/` |
| oauth2-proxy | ⏳ | À déployer avec Authentik (Tier 1) |
| Authentik Clients (OIDC) | 🟢 Ready | Applications/providers dans Terraform — à finaliser après déploiement |

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
| security.yml | ✅ | Gitleaks, Trivy, tfsec, Kubescape |
| Pre-commit hooks | ✅ | `.pre-commit-config.yaml` |

---

## Phase 4: Services MVP ⬜

| Epic | Status | Notes |
|------|--------|-------|
| 4.1 Critical Services (Nextcloud, Vaultwarden, Baïkal) | ⬜ | Dépend de Phase 3 (CLOUD cluster, Authentik, Twingate) |
| 4.2 Media (Comet, Navidrome, Lidarr) | ⬜ | Idem |
| 4.3 Home (Home Assistant, Audiobookshelf, Komga, Romm) | ⬜ | Cluster PROD |
| 4.4 Dashboard (Glance) | ⬜ | CLOUD |
| 4.5 Backup (Velero, Volsync/Restic, ZFS snapshots) | 🟢 Ready | Manifests Velero prêts ; Volsync/ZFS à configurer |

---

## Phase 4b: Stack IA & Services entreprise ⬜

*Objectif : stack IA opérationnelle pour que les agents (OpenClaw, Kilo, Cursor) puissent finaliser le homelab en autonomie. Références : [docs/fiche-stack-ia.md](../../docs/fiche-stack-ia.md), [docs/synthese-outils-entrepreneuse.md](../../docs/synthese-outils-entrepreneuse.md), [stack-ia-et-services-entrepreneuse.md](stack-ia-et-services-entrepreneuse.md).*

| Epic | Status | Notes |
|------|--------|-------|
| 4.6 Stack IA (LiteLLM, DLP, RAG, observabilité, limites) | ⬜ | Dépend de 3.3 (Authentik). Ordre rapide : LiteLLM → DLP → RBAC/limites → observabilité → Authentik JWT → RAG → API search |
| 4.7 Services entreprise (Fleet, Odoo, Migadu, DocuSeal, Docusaurus) | ⬜ | Dépend de 3.3, 3.4. Migadu = Terraform uniquement (externe) |

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
| Proxmox | `terraform/proxmox/` | ✅ Prêt (bpg/proxmox, talos-vms.tf) |

### Kubernetes Manifests

| Category | Location | Applications |
|----------|----------|--------------|
| ArgoCD | `kubernetes/argocd/` | App-of-apps, install, values |
| Infrastructure | `kubernetes/infrastructure/` | cert-manager, cloudflared, twingate, reloader, velero, network-policies |
| Monitoring | `kubernetes/monitoring/` | prometheus, grafana, loki, alertmanager |
| Apps | `kubernetes/apps/` | homepage, authentik, uptime-kuma, fider, docusaurus |

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
| Architecture & run | `docs-site/docs/advanced/architecture.md`, `docs-site/docs/advanced/decisions-and-limits.md` |
| Runbooks | `docs-site/docs/runbooks/` (incidents, rotate-secrets, upgrade-cluster) |
| Secrets | `secrets/README.md` |

---

## Blocking Issues

### ~~Oracle Cloud ARM Capacity~~
- **Status**: ✅ Résolu — Les VMs OCI peuvent maintenant être créées

### ~~Proxmox Storage~~
- **Status**: ✅ Disques reçus — **2×14 To** (miroir) ; **2×2 To** optionnels ; NVMe cache : `scripts/proxmox/setup-nvme-cache.sh`
- **Next**: Exécuter ZFS (ex. `scripts/proxmox/setup-zfs-14tb-only.sh`) puis cache NVMe si besoin.

---

## Next Steps (Priority - OCI-First Strategy)

**Stratégie** : Finaliser OCI avant le local pour sécuriser avant d'exposer le réseau local.

### Phase OCI (Priorité 1)

1. **3.2.1** : Créer VMs K8s sur OCI via Terraform (`terraform/oracle-cloud/`)
2. **3.2.2** : Bootstrapper cluster CLOUD Talos sur OCI
3. **1.3.3** : Enregistrer cluster CLOUD dans Omni (via `omnictl` ou UI manuel)
4. **1.3.4** : Configurer MachineClasses dans Omni
5. **3.4.1** : Finaliser Cloudflare Tunnel (routes pour Omni/Authentik)
6. **3.3.2** + **3.3.3** : Déployer oauth2-proxy et configurer Authentik

### Phase Local (Après OCI sécurisé)

7. **3.4.2** : Déployer Twingate Connector sur CLOUD (accès sécurisé au local)
8. **1.2.2** : Bootstrapper cluster DEV sur Proxmox local
9. **1.3.3** : Enregistrer cluster DEV local dans Omni (via Twingate)
10. **1.4.1** : Installer ArgoCD sur DEV cluster

Voir [oci-first-roadmap.md](oci-first-roadmap.md) pour le plan détaillé.

---

*Dernière mise à jour : 2026-02-04 — Stratégie OCI-first adoptée. Voir [oci-first-roadmap.md](oci-first-roadmap.md) pour le plan détaillé.*
