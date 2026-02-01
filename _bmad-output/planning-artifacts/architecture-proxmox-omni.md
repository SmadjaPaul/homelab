---
date: 2026-01-31
project: homelab
version: 6.0
status: current
lastUpdated: 2026-01-31
note: v6.0 - Authentik as IdP; validation manuelle avant accès apps; apps admin non exposées; service accounts; session travail _bmad-output/planning-artifacts/session-travail-authentik.md
---

# Architecture Document: Homelab Infrastructure with Proxmox + Omni

**Purpose**: This document defines the architectural decisions, implementation patterns, and project structure for a homelab infrastructure built on Proxmox VE with Talos Linux Kubernetes clusters managed by Omni, featuring Dev/Prod environments with CI/CD pipeline.

**Key Inspirations & What We Adopt**:

| Repo | Adopted Patterns | Services/Tools |
|------|------------------|----------------|
| [qjoly/GitOps](https://github.com/qjoly/GitOps) | Omni cluster templates, Talos config | Vault, Volsync, Cloudflare Tunnels |
| [ravilushqa/homelab](https://github.com/ravilushqa/homelab) | Proxmox + Terraform patterns | Gateway API, Home Assistant, Immich |
| [mitchross/talos-argocd-proxmox](https://github.com/mitchross/talos-argocd-proxmox) | ArgoCD sync waves, GPU Operator | Longhorn, sync wave architecture |
| [Mafyuh/iac](https://github.com/Mafyuh/iac) | Security stack, automation | Twingate, Wazuh, n8n, Bitwarden, Trivy |
| [ahinko/home-ops](https://github.com/ahinko/home-ops) | Renovate config, Taskfile | Automated updates, justfile patterns |

---

## 1. Project Context

### Hardware

**Homelab Server** (Proxmox Host):
- **IP**: 192.168.68.51 (Proxmox Web UI: https://192.168.68.51:8006)
- **RAM**: 64GB
- **Storage**: 1TB SSD (system), 2x 20TB HDD (data)
- **GPU**: NVIDIA GPU (for gaming VMs)

**Oracle Cloud** (Always Free Tier):
- **Instances**: 2 ARM VMs (12GB RAM + 2 OCPUs each = 24GB total)
- **Storage**: 139GB block storage
- **Bandwidth**: 10 TB/month egress

### Target Architecture

```
                    ┌─────────────────────────────────────┐
                    │      OMNI (Self-Hosted on OCI)      │
                    │  Single pane of glass for clusters  │
                    │  + Authentik SSO + Cloudflare Tunnel │
                    │  + Workload Proxy (auth services)  │
                    └─────────────────────────────────────┘
                                        │
           ┌────────────────────────────┼────────────────────────────┐
           │                            │                            │
           ▼                            ▼                            ▼
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   Proxmox (Home)    │    │   Oracle Cloud      │    │   CI / GitOps       │
│   PROD Cluster      │    │   CLOUD Cluster     │    │   ────────────────  │
│   ────────────────  │    │   ────────────────  │    │   • Ephemeral DEV   │
│   • Stable services │    │   • Family services │    │     (KubeVirt in     │
│   • Gaming VMs      │    │   • External access │    │     CLOUD)          │
│   • Local storage   │    │   • KubeVirt host   │    │   • create → test   │
│   • 16GB RAM        │    │     for ephemeral   │    │     → destroy        │
│   • No DEV VM 24/7  │    │     DEV (CI)        │    │   • No DEV on Proxmox│
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
           │                            │                            │
           │                            │◄────Twingate/WireGuard────►│
           └────────────────────────────┼────────────────────────────┘
                                        │
                               ┌────────┴────────┐
                               │   GitOps Repo   │
                               └─────────────────┘
```

### Requirements Summary

**Environments**:
- **DEV (éphémère)**: Cluster créé à la volée par la CI via KubeVirt + Omni, test des changements, destruction après MEP si pas d’erreur (pas de cluster DEV permanent sur Proxmox).
- **PROD**: Environnement de production sur Proxmox, reçoit les déploiements après validation sur DEV éphémère.
- **CLOUD**: Cluster Oracle Cloud pour services famille et hébergement d’Omni.

**Target Users**: Developer administrator (Paul), graphic designer, family members (5 people)

---

## 2. Core Architectural Decisions

### 2.1 Hypervisor: Proxmox VE

**Decision**: Proxmox VE as the base hypervisor with Infrastructure as Code

**Rationale**:
- ✅ Web-based VM management (https://192.168.68.51:8006)
- ✅ Terraform provider for IaC (`bpg/proxmox`)
- ✅ GPU passthrough support for gaming VMs
- ✅ ZFS support for storage
- ✅ Mature, stable platform

**IaC Tools**:
- **Terraform/OpenTofu**: VM provisioning, network configuration
- **Packer**: Talos Linux image templates (optional, can use ISO)
- **Ansible**: Initial Proxmox configuration, ZFS setup

---

### 2.2 Kubernetes OS: Talos Linux

**Decision**: Talos Linux for all Kubernetes nodes

**Rationale**:
- ✅ Immutable, API-only OS (no SSH, minimal attack surface)
- ✅ Kubernetes-optimized
- ✅ Atomic updates with rollback
- ✅ Minimal overhead (~200MB footprint)
- ✅ Native Omni integration

**Versions**:
- Talos: Latest stable (1.9.x)
- Kubernetes: Latest stable (1.32.x)

---

### 2.3 Cluster Management: Omni (Self-Hosted on Oracle Cloud)

**Decision**: Self-hosted Omni on Oracle Cloud ARM instance

**Rationale**:
- ✅ Single pane of glass for all clusters (Dev, Prod, Cloud)
- ✅ Declarative cluster configuration
- ✅ SSO authentication (integrated with Authentik)
- ✅ Secure kubeconfig distribution
- ✅ Cluster lifecycle management (upgrades, scaling)
- ✅ Multi-cluster visibility
- ✅ Free hosting on Oracle Cloud Always Free tier
- ✅ Accessible from anywhere (no home network exposure)

**Deployment**: Self-Hosted on Oracle Cloud ARM VM (2GB RAM, 1 OCPU)

**Components**:
- **Omni Server**: Main management interface
- **PostgreSQL**: Database for Omni state
- **Nginx**: HTTPS reverse proxy with Let's Encrypt
- **Authentik Integration**: SSO for all users (SAML ; [Integrate with Omni](https://integrations.goauthentik.io/infrastructure/omni/))

**Key Features**:
- **MachineClass**: Define node profiles (control-plane, worker, GPU worker)
- **ClusterTemplate**: Declarative cluster definitions
- **Infrastructure Provider**: Proxmox integration for auto-provisioning

**References**:
- [Deploy Omni On-Prem](https://omni.siderolabs.com/how-to-guides/self_hosted/)
- [Integrate Authentik with Omni](https://integrations.goauthentik.io/infrastructure/omni/)

---

### 2.3.1 Placement d’Omni : VPC (OCI) vs local (Homelab)

**Contexte** : Omni peut être hébergé sur Oracle Cloud (VPC) ou en local sur le serveur Homelab. Les deux options ont des implications fortes sur la disponibilité et la surface d’attaque.

| Critère | Omni sur VPC (OCI) | Omni en local (Homelab) |
|--------|---------------------|--------------------------|
| **Disponibilité** | Omni toujours joignable (serveur OCI 24/7) | Omni down dès que le serveur est éteint |
| **Administration des clusters** | Possible même quand le serveur est éteint (vacances, absence, économie d’énergie) | Impossible d’administrer les clusters si le serveur est off |
| **Surface d’attaque** | Omni exposé via Cloudflare Tunnel → plus de risque qu’en local | Omni uniquement sur réseau local → moins exposé |
| **Risque opérationnel** | Faible : pas de perte de capacité d’administration | Élevé : serveur off = perte totale de contrôle (talosctl, kubeconfig, upgrades) |

**Recommandation : Omni sur VPC (Oracle Cloud)**.

- **Raison principale** : Si Omni est down (serveur local éteint), on perd la capacité d’administration de *tous* les clusters (PROD Proxmox, CLOUD OCI). Impossible de faire des upgrades Talos, de récupérer un kubeconfig, ou de diagnostiquer à distance. C’est un risque opérationnel majeur pour un homelab où le serveur est régulièrement éteint.
- **Mitigation du risque VPC** : Omni en VPC reste derrière Cloudflare Tunnel (pas de port ouvert direct), avec authentification Authentik (SAML/OIDC). On peut durcir davantage : firewall OCI, IP allowlist Cloudflare, 2FA sur Authentik, audit logs. La surface d’attaque est maîtrisée par la stack Zero Trust.
- **Synthèse** : Héberger Omni en local réduit un peu le risque théorique, mais crée un risque opérationnel réel (perte de contrôle quand le serveur est off). Héberger Omni sur OCI avec Tunnel + SSO offre un bon compromis : disponibilité permanente pour l’administration, risque limité par les contrôles d’accès.

**Référence** : approche similaire à [Omni et KubeVirt (a cup of coffee)](https://a-cup-of.coffee/blog/omni/) — Omni comme point central d’administration, avec possibilité de clusters éphémères via KubeVirt.

---

### 2.4 GitOps: ArgoCD

**Decision**: ArgoCD for GitOps continuous deployment

**Rationale** (vs Flux):
- ✅ Better UI for multi-cluster management
- ✅ ApplicationSets for dynamic app discovery
- ✅ Sync waves for ordered deployments
- ✅ Web UI for visibility and debugging
- ✅ Strong multi-tenancy support

**Key Features**:
- **Sync Waves**: Ordered deployment (infrastructure → core → apps)
- **ApplicationSets**: Auto-discover apps from directory structure
- **Multi-Cluster**: Deploy to Dev/Prod/Cloud from single ArgoCD
- **Self-Management**: ArgoCD manages its own configuration

**Alternative**: Flux CD (used by Cozystack, also excellent)

---

### 2.5 Dev/Prod Workflow (DEV éphémère via KubeVirt + Omni)

**Decision**: Pas de cluster DEV permanent sur Proxmox. Cluster DEV éphémère créé à la volée par la CI via KubeVirt + Omni, puis détruit après les tests (ou après MEP si pas d’erreur).

**Rationale** (inspiré de [Omni et KubeVirt - a cup of coffee](https://a-cup-of.coffee/blog/omni/)) :
- Pas besoin d’une VM DEV qui tourne en permanence sur Proxmox (économie de RAM/CPU).
- La CI crée un cluster DEV dans le cluster CLOUD (KubeVirt), déploie les manifests, lance les tests, puis détruit le cluster.
- Si les tests passent et qu’on merge (MEP), le cluster éphémère est détruit ; la promotion vers PROD se fait via ArgoCD comme aujourd’hui.

**Architecture**:
```
┌──────────────┐     ┌──────────────┐     ┌──────────────────────────┐
│  Git Push    │────▶│  CI Pipeline │────▶│  Omni: create DEV        │
└──────────────┘     └──────────────┘     │  cluster (KubeVirt)      │
                                                  └──────────────────────────┘
                                                  │
                                                  ▼
                                          ┌──────────────┐
                                          │  Deploy +    │
                                          │  Test on DEV │
                                          └──────────────┘
                                                  │
                          ┌───────────────────────┼───────────────────────┐
                          │                       │                       │
                          ▼                       ▼                       ▼
                  ┌──────────────┐         ┌──────────────┐       ┌──────────────┐
                  │  Tests fail  │         │  MEP (merge) │       │  No MEP yet  │
                  │  → Destroy   │         │  → Destroy   │       │  → Keep or   │
                  │  DEV cluster │         │  DEV cluster │       │  destroy     │
                  └──────────────┘         └──────────────┘       └──────────────┘
                                                  │
                                                  ▼
                                          ┌──────────────┐
                                          │ PROD Deploy  │
                                          │ (ArgoCD)     │
                                          └──────────────┘
```

**Implementation**:
```
kubernetes/
├── base/                    # Shared base manifests
│   └── [service]/
├── overlays/
│   ├── dev/                 # Dev-specific patches
│   │   └── [service]/
│   └── prod/                # Prod-specific patches
│       └── [service]/
└── clusters/
    ├── dev/                 # Dev cluster kustomizations
    ├── prod/                # Prod cluster kustomizations
    └── cloud/               # Oracle Cloud cluster
```

**Promotion Strategies**:
1. **Manual**: PR from dev branch to prod branch
2. **Automatic**: Time-based promotion (stable for X hours → auto-promote)
3. **GitOps**: Different branches for dev/prod

---

### 2.6 Networking Architecture

**Decision**: Cilium CNI + Gateway API

**Rationale**:
- ✅ eBPF-based networking (high performance)
- ✅ Gateway API support (modern ingress)
- ✅ Built-in WireGuard encryption
- ✅ Hubble observability
- ✅ Network policies

**Components**:
- **Cilium**: CNI, kube-proxy replacement, network policies
- **MetalLB**: Load balancer for bare metal
- **Gateway API**: Modern ingress (Traefik or Cilium Gateway)
- **external-dns**: Automatic DNS management (Cloudflare)
- **cert-manager**: TLS certificate automation

---

### 2.7 Storage Architecture

**Decision**: Multi-tier storage strategy

**Proxmox (Homelab)**:
```
Storage Tiers:
├── ZFS (local-zfs)          # High-performance, data integrity
│   ├── VM disks
│   └── Container storage
├── Longhorn/OpenEBS         # Kubernetes distributed storage
│   └── Replicated PVCs
└── NFS                      # Shared storage for media
    ├── Films/Series
    ├── Music
    └── Audiobooks
```

**Oracle Cloud**:
```
Storage Tiers:
├── Block Storage (139GB)    # Boot + ephemeral
└── NFS via VPN              # Access to homelab storage
```

**Kubernetes Storage Classes**:
- `local-path`: Local node storage (dev, non-critical)
- `longhorn`: Replicated storage (prod, critical)
- `nfs-media`: NFS for media files (12TB)

---

### 2.8 Security Architecture (2-Tier Authentication)

**Authentication Strategy**:

| Tier | Services | Authentication | Rationale |
|------|----------|----------------|-----------|
| **Tier 1 - Private Data** | Nextcloud, Immich, Vaultwarden, Baïkal, n8n | Authentik SSO + oauth2-proxy | Sensitive data requires centralized identity |
| **Tier 2 - Media/Public** | Navidrome, Komga, Romm, Audiobookshelf, Mealie, Invidious | App-native auth + Cloudflare | Multi-user apps with built-in user management |

**Workload Proxy (Omni)** — option pour l’authentification des services :

Omni propose un **Workload Proxy** qui expose des services Kubernetes via l’interface web Omni, avec authentification gérée par Omni (OIDC). Intérêt pour le homelab :

- **Un seul point d’auth** : pas besoin d’un LoadBalancer par service ni d’un Ingress + certificat SSL dédié pour chaque app.
- **Révocation immédiate** : comme Omni agit en proxy devant l’API et les services, révoquer un utilisateur dans Omni coupe l’accès tout de suite (vs token OIDC qui reste valide jusqu’à expiration).
- **Exposition contrôlée** : les services sont accessibles uniquement via le réseau Wireguard d’Omni, pas directement sur Internet.

Pour activer le Workload Proxy sur un cluster Omni : `features.enableWorkloadProxy: true` dans la config du cluster. Les services à exposer reçoivent une annotation (ex. `omni-kube-service-exposer.sidero.dev/port`, `.../label`). Idéal pour des outils internes (Grafana, ArgoCD, dashboards) qu’on veut protéger par l’identité Omni/Authentik sans déployer oauth2-proxy devant chaque service.

**Choix d’usage** : Workload Proxy peut compléter ou remplacer oauth2-proxy pour certains services (dashboards, outils admin). Pour les apps « métier » (Nextcloud, Vaultwarden, etc.), on garde Authentik SSO + oauth2-proxy ; pour des UIs légères ou internes, le Workload Proxy est une option intéressante. Voir [Omni Workload Proxy (a cup of coffee)](https://a-cup-of.coffee/blog/omni/#workload-proxy).

**IdP retenu : Authentik**.  
Omni sert de proxy (UI, kubeconfig, talosctl) ; Authentik s’y connecte en **SAML** ([Integrate Authentik with Omni](https://integrations.goauthentik.io/infrastructure/omni/)). SSO pour les apps (Nextcloud, Vaultwarden, etc.) via OIDC + oauth2-proxy ou proxy Authentik.

**Flux utilisateur (invitation-only, trafic via Cloudflare)** :  
- **Onboarding par invitation uniquement** : self-registration **désactivée**. L’admin crée une invitation (UI Authentik ou API) et envoie le lien à l’utilisateur ; le flow d’enrollment n’est accessible qu’avec un token d’invitation. Voir `decision-invitation-only-et-acces-cloudflare.md`.  
- **Pas d’accès sans groupes** : tant qu’il n’est pas dans les groupes autorisés, l’utilisateur n’a accès à aucune application ; les policies Authentik refusent l’accès.  
- **Validation / groupes** : après enrollment, l’admin ajoute l’utilisateur aux groupes autorisés (ex. `family-validated`, `family-app-nextcloud`) ; optionnellement un job CI manuel peut appeler l’API Authentik pour ajouter aux groupes ou déclencher le provisionnement.  
- **Après validation** : accès aux apps (Nextcloud, Navidrome, etc.) selon les groupes ; la CI peut créer les comptes dans chaque app (webhook Authentik ou job manuel).  
- **Trafic utilisateur via Cloudflare** : toutes les connexions utilisateurs (auth, portail Authentik, apps protégées) **passent par Cloudflare** (Tunnel) ; pas d’accès direct à l’origine pour les utilisateurs finaux. Règles WAF/config possibles pour renforcer.  
- **Design formalisé** : flux, listes apps, CI, service accounts → `session-travail-authentik.md` §6 ; invitation-only et Cloudflare → `decision-invitation-only-et-acces-cloudflare.md`.

**Applications d’administration non exposées** :  
Les apps d’administration (Authentik Admin, Omni UI, ArgoCD, Grafana admin, Prometheus, etc.) **ne sont pas** exposées aux utilisateurs finaux : pas de lien dans le portail Authentik pour les groupes « famille » ; accès réservé aux admins (groupe dédié) ou par URL/accès restreint (IP, VPN). Les policies Authentik et bindings d’applications distinguent « apps famille » (visibles) et « apps admin » (cachées / réservées).

**Service accounts** :  
Authentik fournit des **service accounts** (utilisateurs de type `service_account`) pour les connexions machine-to-machine (CI, ArgoCD, scripts, n8n, etc.). Droits granulaires par compte ; gestion en **Terraform** (provider goauthentik/authentik) pour `terraform apply`. Secrets stockés dans un secret manager (Bitwarden / Vault), pas en clair dans le repo.

**RBAC & onboarding** : Détail et options (catalogue d’apps, webhook CI) : voir `session-travail-authentik.md` §6 (décisions prises).

**Security Layers**:
1. **Identity**: Authentik SSO (OIDC/SAML) for private services ; validation manuelle avant accès ; apps admin non exposées ; service accounts pour M2M
2. **Access**: oauth2-proxy for Tier 1, app-native auth for Tier 2
3. **RBAC / onboarding**: invitation-only (pas de self-registration) + catalogue apps (hors admin) + CI provisionnement (voir recherche RBAC)
4. **Network**: Cilium network policies, Cloudflare Tunnel (no open ports)
5. **DDoS/WAF**: Cloudflare protection for all public services
6. **Secrets**: External Secrets Operator + Bitwarden (→ Vault later)
7. **Images**: Trivy + Grype scanning in CI/CD
8. **OS**: Talos immutable OS (no SSH)

**Secrets Management**:
- **Phase 1**: Bitwarden Secrets (simple, existing infra)
- **Phase 2**: HashiCorp Vault (self-hosted, advanced)

**Zero Trust Architecture**:
```
┌─────────────────────────────────────────────────────────────────┐
│                    INTERNET                                      │
└─────────────────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Cloudflare      │  │ Twingate        │  │ Authentik SSO   │
│ Tunnel + WAF    │  │ (Zero Trust)    │  │ + oauth2-proxy  │
│ (All Apps)      │  │ (NFS Access)    │  │ (Tier 1 only)   │
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Oracle Cloud / Homelab       │
              │  (No open ports to internet)  │
              └───────────────────────────────┘
```

**Benefits**:
- No port forwarding on home router
- Per-service access control (not VPN = full network)
- Cloudflare WAF + DDoS protection for all services
- Authentik SSO for sensitive data only (reduced complexity)
- Individual user accounts in media apps (playlists, progress tracking)

---

### 2.9 Monitoring & Observability

**Stack**:
- **Metrics**: Prometheus
- **Logs**: Loki + Alloy (Grafana Agent)
- **Dashboards**: Grafana (admin dashboard on Homelab)
- **Alerting**: Alertmanager → ntfy + Telegram → Mobile push
- **User Dashboard**: Glance (Oracle Cloud) for family

**Alerting Flow**:
```
Prometheus → Alertmanager → ntfy (push) + Telegram bot
                              ↓
                         Mobile notifications
```

**Per-Cluster Monitoring**:
- Homelab PROD: Full stack (Prometheus, Grafana, Loki, Alertmanager)
- Oracle Cloud: Lightweight (metrics forwarded to Homelab Grafana)

---

### 2.10 Backup Strategy

**3-2-1 Rule**:
- 3 copies of data
- 2 different storage types
- 1 offsite

**Implementation**:
```
Backup Targets:
├── Local (ZFS snapshots)     # Immediate recovery
├── NAS (rsync/restic)        # Local backup
└── Cloud (OVH Object Storage) # Offsite (3TB free)
    ├── Critical configs
    ├── Databases
    └── Photos (Immich)
```

**Tools**:
- **Velero**: Kubernetes backup (PVs, configs)
- **Restic/Volsync**: File-level backup to S3
- **ZFS snapshots**: Local point-in-time recovery

---

## 3. Cluster Topology

### 3.1 DEV Cluster (éphémère, KubeVirt sur CLOUD)

**Purpose**: Validation CI uniquement. Pas de cluster DEV permanent sur Proxmox.

**Design Philosophy** (inspiré de [Omni et KubeVirt - a cup of coffee](https://a-cup-of.coffee/blog/omni/)) :
- Le cluster CLOUD (Oracle Cloud) héberge KubeVirt.
- Omni dispose d’un **Infrastructure Provider KubeVirt** : à la demande, Omni crée des VMs Talos dans ce cluster Kubernetes.
- La CI déclenche la création d’un cluster DEV via un template Omni (MachineClass KubeVirt), déploie les manifests (ArgoCD ou kubectl), lance les tests, puis détruit le cluster (ou le garde jusqu’à MEP puis destruction).

**Ressources (éphémères)** :
| Rôle | Taille | Notes |
|------|--------|-------|
| Control Plane | 1 node | Créé par Omni KubeVirt provider |
| Workers | 1 node | Idem, selon template |

**Flux typique** :
1. CI (GitHub Actions) : `omnictl cluster template sync -f omni/clusters/dev-ephemeral.yaml` (ou API Omni).
2. Attente que le cluster soit Ready.
3. Récupération du kubeconfig : `omnictl kubeconfig --cluster dev-ephemeral-<run-id>`.
4. Déploiement des manifests + tests (e.g. e2e, smoke).
5. Si MEP ou fin de run : destruction du cluster via Omni (ou TTL automatique si implémenté).

**Prérequis techniques** :
- Cluster CLOUD avec KubeVirt + CDI + storage (ex. LocalPathProvisioner ou autre CSI).
- Omni configuré avec un ServiceAccount « InfraProvider » et le provider KubeVirt (`omni-infra-provider-kubevirt`) pointant vers le kubeconfig du cluster CLOUD.
- MachineClass Omni pour KubeVirt (ex. `hetzner` dans l’article, ici par ex. `oci-kubevirt`).
- Patch Talos pour éviter le chevauchement de CIDR (pod/service) entre l’hôte KubeVirt et les VMs Talos (voir article).

**Deployed Services (sur le cluster éphémère)** :
- Même base que Prod (validates compatibility), overlays dev (replicas=1, ressources réduites).
- Pas de données persistantes critiques ; tests non destructifs ou fixtures.

---

### 3.2 PROD Cluster (Proxmox)

**Purpose**: Stable production services, local access

**Resources**:
| Node | Role | vCPU | RAM | Storage |
|------|------|------|-----|---------|
| talos-prod-cp | Control Plane | 2 | 4GB | 50GB |
| talos-prod-worker-1 | Worker | 6 | 12GB | 200GB |

**Total**: 8 vCPU, 16GB RAM

**Deployed Services**:
- AdGuard Home (DNS + ad blocking)
- Home Assistant (domotique)
- Komga (comics)
- Romm (ROMs)
- Audiobookshelf (audiobooks)
- Prometheus + Grafana + Loki (monitoring)
- ntfy (push notifications)

**Gaming VM** (Proxmox direct, Phase 3: KubeVirt):
- Windows Gaming VM (32GB RAM, GPU passthrough)
- On-demand streaming style GeForce Now (future)

---

### 3.3 CLOUD Cluster (Oracle Cloud)

**Purpose**: Family-shared services, external access, Omni management, **et hôte KubeVirt pour clusters DEV éphémères** (Omni Infrastructure Provider KubeVirt).

**Resources** (Always Free Tier - 24GB RAM, 4 OCPUs, 200GB storage):
| Node | Role | OCPU | RAM | Storage |
|------|------|------|-----|---------|
| oci-mgmt | Omni + Authentik + Infra | 1 | 6GB | 50GB |
| oci-node-1 | Control Plane + Worker | 2 | 12GB | 64GB |
| oci-node-2 | Worker | 1 | 6GB | 75GB |

**Total**: 4 OCPUs, 24GB RAM, 189GB storage

**Management Node (oci-mgmt) - NOT in Kubernetes**:
- **Omni** (self-hosted): Talos cluster management (recommandation : hébergé sur OCI pour disponibilité même quand le serveur Homelab est éteint — voir § 2.3.1).
- **Authentik**: SSO/Identity provider for all services
- **Cloudflare Tunnel**: Zero-trust exposure (no open ports)
- **PostgreSQL**: Database for Omni + Authentik

**KubeVirt sur le cluster CLOUD** (pour DEV éphémère) :
- KubeVirt + CDI installés sur le cluster CLOUD (oci-node-1, oci-node-2).
- Omni Infrastructure Provider KubeVirt : ServiceAccount Omni « InfraProvider », kubeconfig pointant vers le cluster CLOUD, provider `omni-infra-provider-kubevirt` (ex. `ghcr.io/siderolabs/omni-infra-provider-kubevirt`) qui crée les VMs Talos à la demande.
- MachineClass Omni (ex. `oci-kubevirt`) pour les clusters éphémères.
- Storage : LocalPathProvisioner ou autre CSI pour les disques des VMs (voir [article a cup of coffee](https://a-cup-of.coffee/blog/omni/) pour LocalPathProvisioner + patch Talos).

**Deployed Services on Kubernetes Cluster**:

**Namespace: media**
- **Comet** (Real-Debrid addon for Stremio clients) ⚠️ CRITICAL
- Navidrome (music streaming) - storage via NFS to Homelab
- Lidarr (music automation) - storage via NFS to Homelab

> **⚠️ COMET CRITICAL REQUIREMENTS**:
> - **Static IP**: Real-Debrid requires consistent IP (bans accounts for IP changes)
> - **Maximum Uptime**: Family depends on this for streaming
> - **Oracle Cloud Fit**: Static public IP + enterprise uptime + Always Free
> - Stremio is a desktop/mobile client - users install locally and connect to Comet

**Namespace: critical** (Authentik SSO)
- Vaultwarden (passwords)
- Baïkal (CalDAV/CardDAV)
- Twingate Connector (Zero Trust VPN to homelab for NFS)
- oauth2-proxy (SSO enforcement)

**Namespace: collaborative** (Authentik SSO)
- Nextcloud (cloud storage) - storage via NFS to Homelab

**Namespace: dashboard**
- Glance (family dashboard/homepage)

**Namespace: optional** (Phase 2 - deploy as resources allow)
- Immich (photos) - Authentik SSO, storage via NFS to Homelab
- n8n (automation workflows) - Authentik SSO
- Mealie (recipes) - app-native auth
- Invidious (YouTube frontend) - app-native auth

---

## 4. Implementation Patterns

### 4.1 Repository Structure

```
homelab/
├── .github/
│   └── workflows/
│       ├── ci.yml                    # Lint, validate, security scan
│       ├── deploy-dev.yml            # Deploy to DEV on push
│       ├── promote-prod.yml          # Promote DEV → PROD
│       ├── renovate.yml              # Dependency updates
│       └── trivy-scan.yml            # Image security scanning
│
├── terraform/
│   ├── proxmox/
│   │   ├── main.tf                   # Provider configuration
│   │   ├── variables.tf              # Input variables
│   │   ├── outputs.tf                # Output values
│   │   ├── talos-vms.tf              # Talos VM definitions
│   │   ├── gaming-vms.tf             # Gaming VM definitions
│   │   └── network.tf                # Network configuration
│   └── oracle-cloud/
│       ├── main.tf                   # OCI provider
│       ├── compute.tf                # VM instances (mgmt + k8s nodes)
│       └── network.tf                # VCN, subnets
│
├── docker/                            # Docker Compose for management VM
│   └── oci-mgmt/
│       ├── docker-compose.yml        # Omni + Authentik + Cloudflare
│       ├── omni/
│       │   └── config.yaml           # Omni configuration
│       ├── authentik/
│       │   └── config/               # Flows, providers, policies (ou Terraform)
│       ├── cloudflared/
│       │   └── config.yml            # Tunnel configuration
│       └── nginx/
│           └── nginx.conf            # Reverse proxy config
│
├── omni/
│   ├── clusters/
│   │   ├── dev-ephemeral.yaml        # DEV éphémère (KubeVirt, CI)
│   │   ├── prod.yaml                 # PROD cluster template
│   │   └── cloud.yaml                # CLOUD cluster template
│   ├── machine-classes/
│   │   ├── control-plane.yaml        # CP machine class
│   │   ├── worker.yaml               # Standard worker
│   │   └── gpu-worker.yaml           # GPU-enabled worker
│   └── patches/
│       └── cilium-config.yaml        # Cilium configuration
│
├── kubernetes/
│   ├── base/                         # Base manifests (shared)
│   │   ├── argocd/                   # ArgoCD configuration
│   │   │   ├── install.yaml          # ArgoCD installation
│   │   │   ├── root.yaml             # Root application
│   │   │   └── apps/                 # ApplicationSets
│   │   │       ├── infra.yaml        # Infrastructure apps (wave 0-1)
│   │   │       ├── core.yaml         # Core services (wave 2)
│   │   │       ├── monitoring.yaml   # Monitoring (wave 3)
│   │   │       └── apps.yaml         # User applications (wave 4)
│   │   │
│   │   ├── infrastructure/           # Wave 0-1
│   │   │   ├── cilium/
│   │   │   ├── metallb/
│   │   │   ├── cert-manager/
│   │   │   ├── external-dns/
│   │   │   ├── external-secrets/
│   │   │   ├── longhorn/             # Prod storage
│   │   │   └── local-path/           # Dev storage (minimal)
│   │   │
│   │   ├── security/                 # Wave 2
│   │   │   ├── oauth2-proxy/         # SSO enforcement (Tier 1)
│   │   │   ├── twingate/             # Zero Trust connector
│   │   │   ├── vaultwarden/
│   │   │   └── baikal/
│   │   │
│   │   ├── monitoring/               # Wave 3
│   │   │   ├── prometheus/
│   │   │   ├── grafana/
│   │   │   ├── loki/
│   │   │   ├── alloy/                # Grafana agent
│   │   │   ├── alertmanager/
│   │   │   └── ntfy/                 # Push notifications
│   │   │
│   │   └── apps/                     # Wave 4
│   │       ├── media/
│   │       │   ├── comet/            # Real-Debrid addon (CRITICAL)
│   │       │   ├── navidrome/        # Oracle Cloud
│   │       │   └── lidarr/           # Oracle Cloud
│   │       │
│   │       ├── home/                 # Homelab PROD only
│   │       │   ├── adguard-home/     # DNS + ad blocking
│   │       │   ├── home-assistant/
│   │       │   ├── audiobookshelf/   # Moved from Cloud
│   │       │   ├── komga/
│   │       │   └── romm/
│   │       │
│   │       ├── collaborative/
│   │       │   └── nextcloud/
│   │       │
│   │       ├── dashboard/
│   │       │   └── glance/           # Family dashboard
│   │       │
│   │       └── optional/             # Phase 2
│   │           ├── immich/
│   │           ├── n8n/
│   │           ├── mealie/
│   │           └── invidious/
│   │
│   ├── overlays/
│   │   ├── dev/                      # DEV-specific patches
│   │   │   ├── kustomization.yaml
│   │   │   └── patches/
│   │   ├── prod/                     # PROD-specific patches
│   │   │   ├── kustomization.yaml
│   │   │   └── patches/
│   │   └── cloud/                    # Oracle Cloud patches
│   │       ├── kustomization.yaml
│   │       └── patches/
│   │
│   └── clusters/                     # Per-cluster configs
│       ├── dev/
│       │   └── kustomization.yaml    # Points to base + dev overlay
│       ├── prod/
│       │   └── kustomization.yaml    # Points to base + prod overlay
│       └── cloud/
│           └── kustomization.yaml    # Points to base + cloud overlay
│
├── ansible/
│   ├── playbooks/
│   │   ├── proxmox-setup.yml         # Initial Proxmox config
│   │   ├── zfs-setup.yml             # ZFS pool configuration
│   │   └── security-hardening.yml    # Security baseline
│   └── inventory/
│       └── hosts.yml
│
├── packer/                            # VM template building
│   └── talos/
│       ├── talos.pkr.hcl             # Talos image template
│       └── variables.pkr.hcl
│
├── scripts/
│   ├── bootstrap-cluster.sh          # Initial cluster bootstrap
│   ├── promote-to-prod.sh            # DEV → PROD promotion
│   ├── backup.sh                     # Backup automation
│   └── validate-manifests.sh         # Pre-commit validation
│
├── docs/
│   ├── installation.md
│   ├── operations.md
│   ├── troubleshooting.md
│   └── runbooks/
│
├── .taskfiles/                        # Taskfile definitions
│   ├── Taskfile.terraform.yml
│   ├── Taskfile.kubernetes.yml
│   └── Taskfile.backup.yml
│
├── Taskfile.yaml                      # Main taskfile
├── renovate.json                      # Renovate configuration
├── .sops.yaml                         # SOPS encryption config
└── README.md
```

---

### 4.2 ArgoCD Sync Waves

**Wave Architecture** (inspired by mitchross/talos-argocd-proxmox):

```yaml
# Wave 0: Foundation (Networking & Secrets)
- Cilium
- MetalLB
- External Secrets Operator
- cert-manager

# Wave 1: Storage
- Longhorn / OpenEBS
- NFS provisioner

# Wave 2: Core Infrastructure
- external-dns
- Traefik / Gateway API
- Databases (PostgreSQL, Redis)

# Wave 3: Monitoring
- Prometheus
- Grafana
- Loki
- Alertmanager

# Wave 4: Applications
- User workloads
- Media services
- Collaborative tools
```

**Implementation**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cilium
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  # ...
```

---

### 4.3 Service Pattern Template

**Standard service structure**:
```
kubernetes/base/apps/[category]/[service-name]/
├── deployment.yaml           # Deployment resource
├── service.yaml              # Service resource
├── configmap.yaml            # Non-sensitive config
├── external-secret.yaml      # Secrets from Vault/Bitwarden
├── pvc.yaml                  # Persistent storage
├── ingress.yaml              # Ingress/HTTPRoute
├── network-policy.yaml       # Network isolation
├── servicemonitor.yaml       # Prometheus metrics
└── kustomization.yaml        # Kustomize file
```

**Naming Conventions**:
- **Deployment**: `[service-name]`
- **Service**: `[service-name]`
- **ConfigMap**: `[service-name]-config`
- **Secret**: `[service-name]-secrets`
- **PVC**: `[service-name]-data`
- **Ingress**: `[service-name]`

**Mandatory Labels**:
```yaml
labels:
  app.kubernetes.io/name: [service-name]
  app.kubernetes.io/instance: [service-name]
  app.kubernetes.io/component: [component]
  app.kubernetes.io/part-of: homelab
  app.kubernetes.io/managed-by: argocd
```

---

### 4.4 Environment Overlays

**Base → Overlay Pattern**:

```yaml
# kubernetes/overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: default
resources:
  - ../../base/apps/media/navidrome
patches:
  - patch: |
      - op: replace
        path: /spec/replicas
        value: 1
    target:
      kind: Deployment
      name: navidrome
  - path: patches/resources-dev.yaml
```

```yaml
# kubernetes/overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: default
resources:
  - ../../base/apps/media/navidrome
patches:
  - path: patches/resources-prod.yaml
  - path: patches/replicas-prod.yaml
```

---

### 4.5 Terraform Patterns for Proxmox

**Talos VM Definition**:
```hcl
# terraform/proxmox/talos-vms.tf
resource "proxmox_virtual_environment_vm" "talos_prod_cp" {
  name      = "talos-prod-cp"
  node_name = "proxmox"
  
  cpu {
    cores = 2
    type  = "host"
  }
  
  memory {
    dedicated = 4096
  }
  
  disk {
    datastore_id = "local-zfs"
    file_id      = proxmox_virtual_environment_download_file.talos_iso.id
    interface    = "virtio0"
    size         = 50
  }
  
  network_device {
    bridge = "vmbr0"
  }
  
  operating_system {
    type = "l26"  # Linux 2.6+ kernel
  }
  
  tags = ["talos", "kubernetes", "prod", "control-plane"]
}
```

---

### 4.6 Omni Cluster Templates

**Cluster Definition** (inspired by qjoly/GitOps):
```yaml
# omni/clusters/prod.yaml
kind: Cluster
metadata:
  name: prod
  labels:
    environment: production
spec:
  talosVersion: 1.9.0
  kubernetesVersion: 1.32.0
  
  controlPlane:
    machineClass: control-plane
    replicas: 1
    patches:
      - |
        machine:
          network:
            hostname: talos-prod-cp
          install:
            disk: /dev/vda
            
  workers:
    - machineClass: worker
      replicas: 1
      patches:
        - |
          machine:
            network:
              hostname: talos-prod-worker-1
              
    - machineClass: gpu-worker
      replicas: 1
      patches:
        - |
          machine:
            network:
              hostname: talos-prod-gpu
          kubelet:
            extraArgs:
              feature-gates: DevicePlugins=true
```

---

## 5. Services Catalog

### 5.0 Management Services (Oracle Cloud - NOT in K8s)

| Service | RAM | Description | Priority | Source |
|---------|-----|-------------|----------|--------|
| **Omni** | 1GB | Talos cluster management | 🔴 Critical | Sidero Labs |
| **Authentik** | 1GB | SSO/Identity provider (OIDC) | 🔴 Critical | [Various repos] |
| **PostgreSQL** | 512MB | Database for Omni + Authentik | 🔴 Critical | - |
| **Cloudflare Tunnel** | 128MB | Zero-trust ingress (no open ports) | 🔴 Critical | [qjoly, Mafyuh] |
| **Nginx** | 128MB | Reverse proxy + TLS termination | 🔴 Critical | - |

**Total**: ~3GB RAM (runs on oci-mgmt VM, separate from K8s cluster)

**Why Authentik?** (inspired by multiple homelab repos):
- Single Sign-On for all services (Nextcloud, Grafana, ArgoCD, etc.) ; intégration Omni ([Integrate with Omni](https://integrations.goauthentik.io/infrastructure/omni/))
- OIDC/SAML, groupes, policies ; **validation manuelle** avant accès aux apps (pas d’accès direct après inscription)
- **Apps d’administration non exposées** aux utilisateurs finaux (policies / bindings)
- **Service accounts** pour CI, ArgoCD, scripts ; Terraform (goauthentik/authentik) pour IaC
- Webhooks (Notification Transports) pour déclencher la CI (provisionnement)

---

### 5.1 Media Services (Oracle Cloud K8s)

| Service | RAM | Description | Priority | Auth | Storage |
|---------|-----|-------------|----------|------|---------|
| **Comet** | 256MB | Real-Debrid addon for Stremio | 🔴 Critical | - | - |
| **Navidrome** | 512MB | Music streaming (Subsonic compatible) | 🔴 Critical | App-native | NFS → Homelab |
| **Lidarr** | 512MB | Music library automation | 🟡 Important | App-native | NFS → Homelab |

**Total**: ~1.3GB RAM

> **Stremio**: NOT hosted - it's a client app users install on their devices
> **Audiobookshelf**: Moved to Homelab PROD (local access, no need for cloud)

---

### 5.2 Critical Services (Oracle Cloud K8s)

| Service | RAM | Description | Priority | Auth |
|---------|-----|-------------|----------|------|
| **Vaultwarden** | 256MB | Password manager | 🔴 Critical | Authentik SSO |
| **Baïkal** | 256MB | CalDAV/CardDAV | 🔴 Critical | Authentik SSO |
| **Twingate Connector** | 128MB | Zero Trust VPN to homelab (NFS) | 🔴 Critical | - |
| **oauth2-proxy** | 128MB | SSO enforcement for Tier 1 services | 🔴 Critical | - |

**Total**: ~768MB RAM

**Why Twingate over WireGuard?**:
- Zero Trust architecture (no open ports on homelab)
- Per-service access control (not full network access)
- Works through NAT without port forwarding
- Free tier: 5 users (perfect for family)
- Used for NFS access from Oracle Cloud to Homelab storage

---

### 5.3 Collaborative Services (Oracle Cloud K8s)

| Service | RAM | Description | Priority | Auth | Storage |
|---------|-----|-------------|----------|------|---------|
| **Nextcloud** | 2GB | Cloud storage + collaboration | 🔴 Critical | Authentik SSO | NFS → Homelab |

**Total**: ~2GB RAM

> **Removed**: Gitea (GitHub sufficient), Actual Budget, La Suite (not needed)

---

### 5.4 Optional/Automation Services (Oracle Cloud K8s) - Phase 2

| Service | RAM | Description | Priority | Auth | Storage |
|---------|-----|-------------|----------|------|---------|
| **Glance** | 256MB | Family dashboard/homepage | 🟡 Important | App-native | - |
| **Immich** | 2GB | Photo management | 🟢 Phase 2 | Authentik SSO | NFS → Homelab |
| **n8n** | 512MB | Workflow automation | 🟢 Phase 2 | Authentik SSO | - |
| **Mealie** | 512MB | Recipe management | 🟢 Phase 2 | App-native | - |
| **Invidious** | 1GB | YouTube frontend (privacy) | 🟢 Phase 2 | App-native | - |

**Total**: ~4.3GB RAM (deploy after MVP when infra is stable)

**Why n8n?**:
- Automate workflows between services
- Self-hosted alternative to Zapier/Make
- Integrates with 400+ apps
- Useful for: backup notifications, service health checks, family alerts

---

### 5.5 Home Services (Homelab PROD)

| Service | RAM | Description | Priority | Auth |
|---------|-----|-------------|----------|------|
| **AdGuard Home** | 256MB | DNS + ad blocking (DoH/DoT native) | 🔴 Critical | Local |
| **Home Assistant** | 2GB | Home automation | 🔴 Critical | Local |
| **Audiobookshelf** | 1GB | Audiobook management/streaming | 🟡 Important | App-native |
| **Komga** | 2GB | Comics/manga server | 🟡 Important | App-native |
| **Romm** | 1GB | ROM management | 🟡 Important | App-native |

**Total**: ~6.3GB RAM

> **Removed**: Pi-hole (replaced by AdGuard Home), Uptime Kuma (Alertmanager sufficient), Frigate (deferred), Homaar (Glance on Oracle Cloud)
> **Why AdGuard Home over Pi-hole?**: Modern UI, native DoH/DoT, lighter RAM, simpler config

---

### 5.6 Monitoring (Homelab PROD)

| Service | RAM | Description | Priority |
|---------|-----|-------------|----------|
| **Prometheus** | 1GB | Metrics collection | 🔴 Critical |
| **Grafana** | 512MB | Admin dashboards & visualization | 🔴 Critical |
| **Loki** | 512MB | Log aggregation | 🟡 Important |
| **Alertmanager** | 256MB | Alert routing to ntfy + Telegram | 🟡 Important |
| **Alloy** | 256MB | Grafana agent for logs/metrics | 🟡 Important |
| **ntfy** | 128MB | Push notifications | 🟡 Important |

**Total**: ~2.7GB RAM

**Alerting Channels**:
- **ntfy**: Mobile push notifications (self-hosted)
- **Telegram**: Bot for critical alerts

> **Removed**: Wazuh SIEM (overkill for homelab - Talos immutable OS + Cloudflare + Authentik provide sufficient security)

---

### 5.7 CI/CD Security Tools (GitHub Actions)

| Service | RAM | Location | Description | Source |
|---------|-----|----------|-------------|--------|
| **Trivy** | - | CI/CD | Image & config scanning | [Mafyuh] |
| **Grype** | - | CI/CD | Vulnerability scanning | [Mafyuh] |
| **GitGuardian** | - | CI/CD | Secret detection | [Mafyuh] |
| **kubeval** | - | CI/CD | Kubernetes manifest validation | [mitchross] |
| **yamllint** | - | CI/CD | YAML linting | - |

> These run in GitHub Actions, not on cluster resources

---

### 5.8 Gaming (Homelab)

**MVP (Proxmox Direct)**:
| VM | RAM | vCPU | GPU | Storage |
|----|-----|------|-----|---------|
| **Windows Gaming** | 32GB | 8 | Yes (passthrough) | 1TB |

**Phase 3 (KubeVirt - Future)**:
- On-demand VM provisioning via Kubernetes API
- Game streaming style GeForce Now
- VM templates for instant startup
- Web interface to launch gaming sessions

> **Removed**: Linux VM (not needed)
> **Gaming VM is OFF most of the time** - only started for gaming sessions

---

## 6. CI/CD Pipeline

### 6.1 Workflow Overview

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Git Push   │───▶│  CI Pipeline │───▶│  Deploy DEV  │───▶│  Stability   │
│   (main)     │    │  (Validate)  │    │  (Auto)      │    │  Validation  │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
                                                                    │
                                                                    ▼
                                                            ┌──────────────┐
                                                            │  Promote to  │
                                                            │  PROD (Manual│
                                                            │  or Auto)    │
                                                            └──────────────┘
```

### 6.2 GitHub Actions Workflows

**CI Pipeline** (`.github/workflows/ci.yml`) — inchangé : validation manifests, lint, Trivy.

**Ephemeral DEV (create → test → destroy)** (`.github/workflows/deploy-dev-ephemeral.yml` ou extension de `deploy-dev.yml`):
```yaml
# Idée : créer cluster DEV via Omni (KubeVirt), déployer, tester, détruire
jobs:
  ephemeral-dev:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Create ephemeral DEV cluster (Omni + KubeVirt)
        run: |
          omnictl cluster template sync -f omni/clusters/dev-ephemeral.yaml
          # ou appel API Omni pour créer cluster avec ID unique (e.g. $GITHUB_RUN_ID)
      - name: Wait for cluster Ready
        run: |
          omnictl get cluster dev-ephemeral-${{ github.run_id }} --wait
      - name: Get kubeconfig
        run: omnictl kubeconfig --cluster dev-ephemeral-${{ github.run_id }} > kubeconfig
      - name: Deploy and test
        run: |
          kubectl apply -f kubernetes/...  # ou ArgoCD sync
          # run e2e / smoke tests
      - name: Destroy ephemeral cluster (on success or failure)
        if: always()
        run: omnictl cluster delete dev-ephemeral-${{ github.run_id }}
```

**Promote to PROD** (`.github/workflows/promote-prod.yml`) : après validation sur DEV éphémère (MEP sans erreur), promotion vers PROD via ArgoCD (inchangé).

---

## 7. Renovate Configuration

**Automated dependency updates** (inspired by ahinko/home-ops):

```json5
// renovate.json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    "docker:enableMajor",
    ":semanticCommits",
    ":automergeDigest",
    ":automergeBranch"
  ],
  "kubernetes": {
    "fileMatch": ["kubernetes/.+\\.ya?ml$"]
  },
  "helm-values": {
    "fileMatch": ["kubernetes/.+\\.ya?ml$"]
  },
  "packageRules": [
    {
      "description": "Auto-merge minor/patch for trusted packages",
      "matchUpdateTypes": ["minor", "patch"],
      "matchPackageNames": ["ghcr.io/linuxserver/*"],
      "automerge": true
    },
    {
      "description": "Group Prometheus stack updates",
      "matchPackagePatterns": ["prometheus", "grafana", "alertmanager"],
      "groupName": "monitoring-stack"
    }
  ]
}
```

---

## 8. Resource Allocation Summary

### Homelab (64GB RAM)

| Component | RAM | Notes |
|-----------|-----|-------|
| **Proxmox Host** | 4GB | OS overhead |
| **ZFS ARC Cache** | 8GB | Performance |
| **DEV Cluster** | 0GB | Éphémère sur CLOUD (KubeVirt), pas de VM Proxmox dédiée |
| **PROD Cluster** | 16GB | Production services |
| **Gaming VM** | 32GB | When active (OFF most of the time) |
| **Reserve** | 4GB | Buffer |

**PROD Cluster Breakdown** (~16GB):
| Service | RAM |
|---------|-----|
| K8s overhead | 2GB |
| AdGuard Home | 256MB |
| Home Assistant | 2GB |
| Audiobookshelf | 1GB |
| Komga | 2GB |
| Romm | 1GB |
| Prometheus | 1GB |
| Grafana | 512MB |
| Loki | 512MB |
| Alertmanager | 256MB |
| Alloy | 256MB |
| ntfy | 128MB |
| Reserve | ~5GB |

**Normal Operation**: ~24GB used (PROD active, pas de cluster DEV permanent, Gaming OFF)
**Testing Mode (CI)** : cluster DEV éphémère créé sur CLOUD (KubeVirt), pas de RAM Proxmox dédiée.
**Gaming Mode**: ~48GB used (Gaming VM + PROD)

---

### Oracle Cloud (24GB RAM, 4 OCPUs)

**Management VM (oci-mgmt)** - Docker, NOT Kubernetes:
| Component | RAM | Notes |
|-----------|-----|-------|
| **Omni** | 1GB | Cluster management |
| **Authentik** | 1GB | SSO/Identity |
| **PostgreSQL** | 512MB | Database |
| **Cloudflare Tunnel** | 128MB | Zero-trust ingress |
| **Nginx** | 128MB | Reverse proxy |
| **Reserve** | 2GB | Buffer |
| **Total** | **~5GB** | 1 OCPU |

**Kubernetes Cluster (oci-node-1 + oci-node-2)** - MVP:
| Component | RAM | Notes |
|-----------|-----|-------|
| **K8s Overhead** | 2GB | Control plane, Cilium |
| **Media Services** | 1.3GB | Comet, Navidrome, Lidarr |
| **Critical Services** | 0.8GB | Vaultwarden, Baïkal, Twingate, oauth2-proxy |
| **Collaborative** | 2GB | Nextcloud |
| **Dashboard** | 256MB | Glance |
| **Reserve** | ~6GB | Buffer for Phase 2 services |
| **Total MVP** | **~12GB** | 3 OCPUs |

**Phase 2 Addition**:
| Component | RAM | Notes |
|-----------|-----|-------|
| **Immich** | 2GB | Photos |
| **n8n** | 512MB | Automation |
| **Mealie** | 512MB | Recipes |
| **Invidious** | 1GB | YouTube |
| **Total Phase 2** | **~4GB** | |

**Grand Total**: ~16-19GB RAM, 4 OCPUs ✅ Within Always Free limits

---

## 9. Implementation Roadmap

### Phase 1: Foundation
- [ ] Terraform Proxmox VMs (PROD nodes only ; pas de VM DEV dédiée)
- [ ] Omni setup on Oracle Cloud (self-hosted, recommandation § 2.3.1)
- [ ] PROD cluster bootstrap (Talos + Kubernetes)
- [ ] ArgoCD installation
- [ ] Cilium CNI deployment

### Phase 2: Core Infrastructure
- [ ] Storage (Longhorn/OpenEBS)
- [ ] cert-manager + external-dns
- [ ] External Secrets Operator + Bitwarden
- [ ] Monitoring stack (Prometheus, Grafana, Loki, ntfy)
- [ ] AdGuard Home (DNS)

### Phase 3: PROD Cluster + Oracle Cloud + DEV éphémère
- [ ] PROD cluster bootstrap
- [ ] Terraform OCI instances
- [ ] Oracle Cloud K8s cluster (CLOUD)
- [ ] KubeVirt + CDI + storage (LocalPathProvisioner ou CSI) sur CLOUD
- [ ] Omni Infrastructure Provider KubeVirt (MachineClass, ServiceAccount, provider container)
- [ ] Authentik SSO + Cloudflare Tunnel
- [ ] Twingate connector for NFS access
- [ ] CI/CD pipeline : workflow ephemeral DEV (create → test → destroy)

### Phase 4: Services MVP
- [ ] Critical: Vaultwarden, Baïkal
- [ ] Collaborative: Nextcloud
- [ ] Media: Comet, Navidrome, Lidarr
- [ ] Home: Home Assistant, Komga, Romm, Audiobookshelf
- [ ] Dashboard: Glance (family), Grafana (admin)

### Phase 5: Optional Services
- [ ] Immich (photos)
- [ ] n8n (automation)
- [ ] Mealie (recipes)
- [ ] Invidious (YouTube)

### Phase 6: Gaming & Advanced
- [ ] GPU passthrough setup
- [ ] Windows Gaming VM (Proxmox direct)
- [ ] KubeVirt integration (on-demand gaming)
- [ ] Backup automation

---

## 10. Validation Checklist

### Pre-Deployment
- [ ] All manifests pass `kubeval`
- [ ] No secrets in Git (checked by GitGuardian)
- [ ] Trivy scan passes (no critical vulnerabilities)
- [ ] YAML lint passes

### Post-Deployment
- [ ] All pods Running/Ready
- [ ] Ingress accessible
- [ ] TLS certificates valid
- [ ] Prometheus scraping metrics
- [ ] Alertmanager configured

---

**Document Status**: ✅ **VALIDATED & READY FOR IMPLEMENTATION**

Architecture v6.0 validated on 2026-01-31. Key changes from v5.0:
- **IdP : Authentik** (remplace Keycloak). Intégration Omni SAML, webhooks, service accounts, Terraform.
- **Flux utilisateur** : **invitation-only** (pas de self-registration) ; trafic utilisateur **via Cloudflare** ; **apps admin non exposées** aux utilisateurs finaux.
- **Design Authentik** : flux, listes apps, CI, service accounts → `session-travail-authentik.md` §6 ; invitation-only et Cloudflare → `decision-invitation-only-et-acces-cloudflare.md`.

This design provides:
- Pas de VM DEV 24/7 sur Proxmox (économie de ressources).
- CI-driven ephemeral DEV (create → test → destroy) inspiré de [Omni et KubeVirt - a cup of coffee](https://a-cup-of.coffee/blog/omni/).
- Workload Proxy comme option d’auth pour services internes.
- Omni sur OCI pour disponibilité et administration à distance.

Begin with Phase 1: Terraform Proxmox VMs and Omni setup ; puis KubeVirt + Omni provider sur CLOUD pour DEV éphémère.
