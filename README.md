# Homelab Infrastructure

> **100% GitOps** - Infrastructure hybride OCI + Home entièrement automatisée via GitHub Actions

Déployez une infrastructure complète (Cloudflare, OCI, Kubernetes, applications) en **1 clic et 40 minutes**.

[![Deploy](https://img.shields.io/badge/Deploy-Infrastructure-success?style=for-the-badge&logo=github-actions)](https://github.com/votre-user/homelab/actions/workflows/deploy-infra.yml)

## 🏗️ Architecture

```
Internet
    │
    ▼
Cloudflare (DNS/WAF/Tunnel)
    │
    ├──────────────┬──────────────┐
    │              │              │
    ▼              ▼              ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│ VM-Hub   │ │ K8s CP   │ │ K8s      │
│ 1 OCPU   │ │ 1 OCPU   │ │ Workers  │
│ 4GB RAM  │ │ 6GB RAM  │ │ 2×1 OCPU │
├──────────┤ ├──────────┤ │ 14GB RAM │
│ Omni     │ │ Talos    │ ├──────────┤
│ Tailscale│ │ K8s      │ │ Apps     │
│ Comet    │ └──────────┘ │ DB       │
└──────────┘              └──────────┘
    │                           │
    └───────────┬───────────────┘
                │ Tailscale
                ▼
         ┌──────────────┐
         │ Home Cluster │
         │ (Proxmox)    │
         └──────────────┘
```

**OCI Free Tier (4 VMs, 4 OCPU, 24GB RAM):**
- **oci-hub** (1 OCPU, 4GB): Omni + Tailscale + Comet
- **talos-cp-1** (1 OCPU, 6GB): K8s Control Plane
- **talos-worker-1** (1 OCPU, 8GB): Apps lourdes (Nextcloud, Matrix)
- **talos-worker-2** (1 OCPU, 6GB): DB + apps légères

## 📁 Structure du Repository

```
.
├── .github/
│   └── workflows/          # GitHub Actions
│       ├── lint.yaml       # Validation YAML/Terraform
│       ├── security.yaml   # Scan Trivy/Checkov
│       ├── terraform.yaml  # Plan/Apply Terraform
│       ├── flux-diff.yaml  # Diff Flux CD
│       └── renovate.yaml   # Auto-update deps
│
├── kubernetes/             # Manifests Kubernetes (Flux CD)
│   ├── apps/
│   │   ├── business/       # Authentik, Odoo, FleetDM
│   │   ├── productivity/   # Nextcloud, Matrix, Immich
│   │   ├── media/          # Jellyfin, Comet
│   │   ├── infrastructure/ # Cloudflare, cert-manager
│   │   └── automation/     # Renovate, n8n
│   ├── clusters/
│   │   └── oci-hub/        # Configuration cluster OCI
│   └── infrastructure/     # Charts et manifests communs
│
├── terraform/              # Infrastructure as Code
│   ├── oracle-cloud/       # VMs OCI (4 VMs Free Tier)
│   ├── cloudflare/         # DNS, Tunnel, Access
│   └── proxmox/            # VMs Home (futur)
│
├── scripts/                # Scripts utilitaires
│   ├── setup-doppler.sh    # Setup projets Doppler
│   ├── bootstrap-phase2.sh # Bootstrap Omni + K8s
│   └── bootstrap.sh
│
├── docs/                   # Documentation
│   ├── DEPLOYMENT-GUIDE.md      # Guide déploiement complet
│   ├── DEPLOYMENT-ARCHITECTURE.md # Dépendances et phases
│   ├── ACCESS-ARCHITECTURE.md   # Méthodes d'accès
│   └── cloudflare.md            # Config Cloudflare
│
├── doppler.yaml            # Configuration projets Doppler
└── README.md
```

## 🔄 Workflows GitHub Actions

| Workflow | Déclencheur | Description |
|----------|-------------|-------------|
| **[deploy-infra.yml](.github/workflows/deploy-infra.yml)** | `workflow_dispatch` | **Déploiement complet** - 4 phases (Cloudflare → OCI → Omni → K8s) |
| **[terraform.yml](.github/workflows/terraform.yml)** | Push/PR sur `terraform/**` | Plan/Apply Terraform par module (cloudflare, oci, etc.) |
| **[lint.yml](.github/workflows/lint.yml)** | Push/PR | Validation YAML et Terraform |
| **[security.yml](.github/workflows/security.yml)** | Push/PR + Weekly | Scan Trivy et Checkov |
| **[flux-diff.yml](.github/workflows/flux-diff.yml)** | Push/PR sur `kubernetes/**` | Diff entre Git et cluster K8s |
| **[renovate.yml](.github/workflows/renovate.yml)** | Daily | Mise à jour automatique des dépendances |

### Environments (Protection)

Les workflows utilisent des **environments** GitHub avec approbation manuelle:

- `cloudflare` - Modifications DNS/Tunnel
- `production` - VMs OCI
- `omni` - Bootstrap Kubernetes
- `kubernetes` - Déploiement applications

Configurez dans: Settings → Environments

## 🚀 Déploiement (100% CI/CD)

### Option 1: GitHub Actions (Recommandé)

#### Prérequis (1 fois)

1. **Forker ce repository** sur votre compte GitHub

2. **Configurer les secrets GitHub** (voir [docs/GITHUB_SECRETS.md](docs/GITHUB_SECRETS.md)):
   ```bash
   # Vérifier les secrets manquants
   ./scripts/check-secrets.sh

   # Ou manuellement sur GitHub:
   # Settings → Secrets and variables → Actions
   ```

3. **Créer un compte Omni** (pour la phase Kubernetes):
   - Aller sur https://omni.siderolabs.io
   - Noter l'endpoint: `https://xxx.omni.siderolabs.io:50001`
   - Générer une clé API: Settings → Keys → Generate

#### Déploiement (1 clic)

**Via GitHub UI:**
```
GitHub → Actions → "Deploy Infrastructure" → Run workflow → phase: all
```

**Via CLI:**
```bash
gh workflow run deploy-infra.yml -f phase=all
```

**Durée: ~40 minutes**
- **Phase 1** (5 min): Cloudflare (DNS, Tunnel, Access)
- **Phase 2** (5 min): OCI VMs (Ubuntu temporaire)
- **Phase 3** (20 min): Omni Bootstrap (génération image + import OCI)
- **Phase 4** (10 min): Kubernetes apps (Flux CD)

### Option 2: Local (Développement)

```bash
# 1. Vérifier les prérequis
./scripts/prepare-deployment.sh

# 2. Déployer tout
./scripts/deploy.sh all

# Ou par phases:
./scripts/deploy.sh cloudflare    # Phase 1
./scripts/deploy.sh oci           # Phase 2
./scripts/deploy.sh omni          # Phase 3
./scripts/deploy.sh k8s           # Phase 4
```

## 🏗️ Architecture des Services

### VM Hub (oci-hub) - 1 OCPU / 4GB

Services **infrastructure** nécessaires au bootstrap et à l'administration:

| Service | Port | Description | Pourquoi sur VM ? |
|---------|------|-------------|-------------------|
| **Omni** | 50000/50001 | Control Plane Kubernetes | Doit exister avant K8s |
| **Tailscale** | - | VPN Subnet Router | Accès admin réseau privé |
| **Comet** | 8080 | Streaming (Stremio) | Latence minimale |

**Fichier:** `terraform/oracle-cloud/templates/hub-cloud-init.sh`

### Cluster Kubernetes (3 VMs) - 3 OCPU / 20GB

Toutes les **applications** et l'infrastructure K8s:

| Service | Description | Accès |
|---------|-------------|-------|
| **Cloudflared** | Tunnel vers Cloudflare | Internal |
| **Traefik** | Ingress Controller | Internal |
| **Authentik** | Identity Provider (SSO) | https://auth.smadja.dev |
| **Nextcloud** | Cloud Storage | https://cloud.smadja.dev |
| **Matrix** | Chat | https://chat.smadja.dev |

**Gestion:** GitOps via Flux CD

### Gestion du Trafic

```
Internet
    │
    ├─► *.smadja.dev ──► Cloudflare Tunnel ──► Traefik ──► Apps K8s
    │                                                    (Nextcloud, etc.)
    │
    ├─► [VM-IP]:8080 ──► Comet (Streaming, direct)
    │
    └─► Tailscale VPN ──► Omni + kubectl + SSH (Admin only)
```

**📖 Détails:** [docs/VM-VS-K8S.md](docs/VM-VS-K8S.md) | [docs/NETWORK-ARCHITECTURE.md](docs/NETWORK-ARCHITECTURE.md)

**📖 Documentation:**
- [docs/GITHUB_SECRETS.md](docs/GITHUB_SECRETS.md) - Liste complète des secrets
- [docs/VM-VS-K8S.md](docs/VM-VS-K8S.md) - Ce qui tourne sur VM vs Kubernetes
- [docs/NETWORK-ARCHITECTURE.md](docs/NETWORK-ARCHITECTURE.md) - Gestion du trafic et réseau
- [docs/FULLY-AUTOMATED-ARCHITECTURE.md](docs/FULLY-AUTOMATED-ARCHITECTURE.md) - Architecture CI/CD

## 🔐 Secrets Management

**1 projet Doppler = 1 service** pour granularité maximale:

```
infrastructure/           # Secrets core + tokens
├── CLOUDFLARE_API_TOKEN
├── OCI_CLI_*
├── TAILSCALE_AUTH_KEY
└── DOPPLER_TOKEN_SERVICE_*

service-authentik/      # AUTHENTIK_*
service-nextcloud/      # NEXTCLOUD_*
service-comet/          # COMET_*, RD_API_KEY
...
```

Synchronisation automatique vers Kubernetes via External Secrets Operator.

## 🌐 Architecture d'Accès

| Méthode | Services | Utilisateurs | Auth |
|---------|----------|--------------|------|
| **Cloudflare Tunnel** | Nextcloud, Matrix, etc. | Famille/Amis | Authentik |
| **Direct + CF Access** | Comet (streaming) | Toi | CF Access |
| **Tailscale VPN** | Omni, kubectl, SSH | Toi (admin) | Device |

## 🔄 Workflows GitHub

### Lint & Validation
- **Trigger:** Push/PR sur `main`
- **Action:** Validation YAML, Terraform fmt/validate

### Sécurité
- **Trigger:** Push/PR + Weekly
- **Action:** Scan Trivy (K8s manifests, Terraform), Checkov

### Terraform
- **Trigger:** Changements dans `terraform/`
- **Action:** Plan automatique, Apply manuel (environment protection)

### Flux Diff
- **Trigger:** Changements dans `kubernetes/`
- **Action:** Affiche le diff entre Git et cluster

### Renovate
- **Trigger:** Daily
- **Action:** Mise à jour automatique des dépendances (Helm charts, images)

## 📊 Ressources

| Ressource | Limite | Utilisé |
|-----------|--------|---------|
| VMs ARM | 4 | 4 ✅ |
| OCPU | 4 | 4 ✅ |
| RAM | 24GB | 24GB ✅ |

## 📝 Documentation

- **[DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md)** - Guide déploiement étape par étape
- **[DEPLOYMENT-ARCHITECTURE.md](docs/DEPLOYMENT-ARCHITECTURE.md)** - Dépendances et ordre de déploiement
- **[ACCESS-ARCHITECTURE.md](docs/ACCESS-ARCHITECTURE.md)** - Méthodes d'accès (Tunnel/Direct/VPN)
- **[cloudflare.md](docs/cloudflare.md)** - Configuration Cloudflare Tunnel

## 🆘 Dépannage

**Voir les logs:**
```bash
# Kubernetes
kubectl logs -n <namespace> deployment/<app>

# Doppler
doppler secrets -p <project>

# Terraform
cd terraform/oracle-cloud && terraform state list
```

## 🎯 Roadmap

Voir [ROADMAP.md](ROADMAP.md) pour les détails.

---

**⚠️ Work in Progress** - Ce projet est en construction active.
