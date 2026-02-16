# GitOps Homelab - Architecture Hybride

> **Infrastructure hybride OCI + Home avec gestion granulaire des secrets**
>
> ⚠️ **IMPORTANT**: Lisez la section [Dépendances & Bootstrap](#-dépendances--bootstrap) avant de commencer!

## 🏗️ Architecture

```
Internet
    │
    ▼
Cloudflare (DNS/WAF/Access)
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

## ⚠️ Dépendances & Bootstrap

**⚠️ ATTENTION**: Ce déploiement a des dépendances complexes. L'ordre est CRITIQUE.

### Problème "Omni ↔ Authentik"

❌ **NE PAS FAIRE**: Configurer Omni avec Authentik avant qu'Authentik existe
✅ **ORDRE CORRECT**: Omni (auth locale) → Cluster K8s → Authentik → (optionnel) migrer Omni

### Ordre de Déploiement

```
Phase 0: Prérequis
  └─ Doppler setup, outils CLI

Phase 1: Infrastructure (Terraform)
  └─ 4 VMs créées (Omni en auth locale)

Phase 2: Omni Configuration (Manuel)
  └─ Web UI → Cluster "oci-hub" → Image Talos
  └─ Script: ./scripts/bootstrap-phase2.sh

Phase 3: K8s Bootstrap (Manuel)
  └─ Flux install → Secret Doppler → External Secrets
  └─ Script: ./scripts/bootstrap-phase2.sh (suite)

Phase 4: Infra Core (GitOps)
  └─ Cert-manager → Cloudflare Tunnel → Traefik
  └─ kubectl apply -k kubernetes/clusters/oci-hub

Phase 5: Authentik (GitOps + Manuel)
  └─ Déployer via GitOps
  └─ Configurer manuellement (users, apps)

Phase 6+: Apps (GitOps)
  └─ Nextcloud, Matrix, etc.
```

**📖 Documentation détaillée**: [docs/DEPLOYMENT-ARCHITECTURE.md](docs/DEPLOYMENT-ARCHITECTURE.md)

## 📁 Structure du Repository

```
GitOps-main/
├── apps/                      # Applications par type
│   ├── business/             # Services professionnels
│   │   ├── authentik/        # IdP
│   │   ├── odoo/             # ERP
│   │   ├── fleetdm/          # MDM
│   │   └── vaultwarden/      # Passwords
│   ├── productivity/         # Services famille
│   │   ├── nextcloud/        # Cloud
│   │   ├── matrix/           # Chat
│   │   ├── immich/           # Photos
│   │   └── gitea/            # Git
│   ├── media/                # Médias
│   │   ├── comet/            # Streaming (OCI)
│   │   └── jellyfin/         # Media server (Home)
│   ├── infrastructure/       # Services core
│   │   ├── external-secrets/ # Doppler sync
│   │   ├── cert-manager/     # TLS
│   │   ├── cloudflare/       # Tunnel + External DNS
│   │   └── traefik/          # Ingress
│   └── automation/           # DevOps
│       ├── renovate/         # Updates
│       └── n8n/              # Workflows
│
├── clusters/                 # 1 dossier = 1 cluster
│   ├── oci-hub/             # Cluster OCI
│   │   ├── flux-system/     # Bootstrap
│   │   ├── infra/           # Namespace infra
│   │   ├── databases/       # PostgreSQL, Redis
│   │   ├── business/        # Apps pro
│   │   └── productivity/    # Apps perso
│   └── home-prod/           # Cluster Home (Proxmox)
│
├── infrastructure/          # Composants réutilisables
│   ├── charts/             # Helm charts
│   ├── manifests/          # Manifests bruts
│   └── policies/           # Kyverno/OPA
│
├── terraform/              # IaC
│   └── oracle-cloud/
│       ├── templates/      # Cloud-init scripts
│       ├── compute.tf      # 4 VMs
│       └── variables.tf
│
├── scripts/                # Utilitaires
│   ├── bootstrap.sh              # Déploiement complet (TODO)
│   ├── bootstrap-phase2.sh       # Phase 2 & 3 (Manuel)
│   └── setup-doppler.sh          # Setup Doppler projects
│
├── docs/                   # Documentation
│   ├── ARCHITECTURE.md              # Architecture générale
│   ├── ACCESS-ARCHITECTURE.md       # Accès (Tunnel/Direct/VPN)
│   └── DEPLOYMENT-ARCHITECTURE.md   # Guide déploiement détaillé
│
└── doppler.yaml           # Configuration secrets
```

## 🔐 Secrets Management (1 projet = 1 service)

Chaque service a son propre projet Doppler pour une granularité maximale.

```
Doppler Projects:
├── infrastructure           # Secrets core + tokens autres projets
│   └── DOPPLER_TOKEN_SERVICE_* (auto-générés)
├── service-authentik       # AUTHENTIK_*
├── service-nextcloud       # NEXTCLOUD_*
├── service-comet           # COMET_*, RD_API_KEY
├── service-jellyfin        # JELLYFIN_*
├── service-odoo            # ODOO_*
├── service-fleetdm         # FLEET_DM_*
├── service-matrix          # MATRIX_*
├── service-immich          # IMMICH_*
├── service-vaultwarden     # VAULTWARDEN_*
├── service-gitea           # GITEA_*
├── service-litellm         # LITELLM_*
├── service-openwebui       # OPENWEBUI_*
└── backup-kopia            # KOPIA_*, BACKBLAZE_*
```

### Workflow

1. **Doppler** (Source of Truth)
   ```bash
   doppler secrets set AUTHENTIK_SECRET_KEY="xxx" -p service-authentik
   ```

2. **External Secrets Operator** sync vers Kubernetes
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   spec:
     secretStoreRef:
       name: doppler-service-authentik  # 1 store par service
   ```

3. **Applications** utilisent les secrets Kubernetes

## 🚀 Quick Start (Version Corrigée)

### Phase 0: Prérequis

```bash
# macOS
brew install terraform kubectl helm talosctl doppler fluxcd/tap/flux

# Doppler CLI
curl -sLf https://cli.doppler.com/install.sh | sh
doppler login
```

### Phase 1: Setup Doppler

```bash
cd GitOps-main
./scripts/setup-doppler.sh

# Ajouter les secrets dans l'interface Doppler:
# - infrastructure: OCI_CLI_*, CLOUDFLARE_*, TAILSCALE_*, GRAFANA_*
# - service-*: Laisser vide pour l'instant (seront remplis plus tard)
```

### Phase 2: Déployer Infrastructure (Terraform)

```bash
cd terraform/oracle-cloud

cp terraform.tfvars.example terraform.tfvars
# Éditer terraform.tfvars avec:
# - compartment_id
# - ssh_public_key
# - tailscale_auth_key (optionnel pour l'instant)

# Déployer VMs
doppler run -- terraform init
doppler run -- terraform apply

# Résultat: 4 VMs créées, Omni accessible
```

### Phase 3: Configuration Omni + Bootstrap K8s

```bash
cd ../..  # Retour à GitOps-main

# Lancer le script de bootstrap Phase 2 & 3
./scripts/bootstrap-phase2.sh

# Ce script va:
# 1. Vous guider pour configurer Omni (créer cluster, générer image Talos)
# 2. Mettre à jour terraform.tfvars avec talos_image_id
# 3. Re-appliquer Terraform pour déployer Talos
# 4. Récupérer kubeconfig
# 5. Installer Flux CD
# 6. Créer secret Doppler
# 7. Déployer External Secrets Operator
```

### Phase 4: Déployer Infrastructure Core (GitOps)

```bash
# Une fois bootstrap-phase2.sh terminé:
kubectl apply -k kubernetes/clusters/oci-hub

# Vérifier
kubectl get pods -n infra
flux get kustomizations
```

### Phase 5: Authentik

```bash
# 1. Ajouter secrets dans Doppler (service-authentik)
# 2. Déployer via GitOps (déjà dans kustomization.yaml, décommenter)
# 3. Configurer manuellement via https://auth.smadja.dev
```

## 🌐 Architecture d'Accès (qjoly/GitOps style)

**Basé sur l'architecture de référence avec Cloudflare Tunnel + External DNS:**

```
Internet
    │
    ▼
Cloudflare (DNS/WAF/Proxy)
    │
    ▼
Cloudflare Tunnel ──► K8s Cluster
    │
    ├─ External DNS (création auto des records)
    │
    └─ Traefik Ingress Controller
         │
         └─ Services (Nextcloud, Matrix, etc.)
```

### Méthodes d'accès

| Méthode | Services | Utilisateurs | Auth |
|---------|----------|--------------|------|
| **Cloudflare Tunnel** | Tous les services web | Famille/Amis | Authentik |
| **Direct + CF Access** | Comet (streaming) | Toi | CF Access (email) |
| **Tailscale VPN** | Omni, kubectl, SSH | Toi (admin) | Device + 2FA |

### Fonctionnement

1. **Cloudflare Tunnel** : Connecte le cluster à Cloudflare (pas d'IP publique exposée)
2. **External DNS** : Crée automatiquement les DNS records dans Cloudflare
3. **Wildcard** : `*.smadja.dev` → Tunnel → Traefik → Services
4. **Ingress annotations** : Configurent le DNS automatiquement

**📖 Détail** : [docs/ACCESS-ARCHITECTURE.md](docs/ACCESS-ARCHITECTURE.md) + [docs/cloudflare.md](docs/cloudflare.md)

**📖 Détail**: [docs/ACCESS-ARCHITECTURE.md](docs/ACCESS-ARCHITECTURE.md)

## 📊 Ressources Free Tier

| Ressource | Limite | Utilisé | Disponible |
|-----------|--------|---------|------------|
| VMs ARM   | 4      | 4       | 0 ✅       |
| OCPU      | 4      | 4       | 0 ✅       |
| RAM       | 24GB   | 24GB    | 0 ✅       |
| Storage   | 200GB  | ~150GB  | 50GB       |

## 🔧 Services Planifiés

### Phase 1: Core (Week 1-2)
- [ ] External Secrets Operator
- [ ] cert-manager
- [ ] Traefik
- [ ] Cloudflare Tunnel

### Phase 2: Auth (Week 3)
- [ ] Authentik (IdP)
- [ ] Configuration SSO

### Phase 3: Business (Week 4-6)
- [ ] Nextcloud
- [ ] Vaultwarden
- [ ] Odoo
- [ ] FleetDM

### Phase 4: Famille (Week 7-8)
- [ ] Matrix
- [ ] Immich
- [ ] Comet

### Phase 5: Home (Week 9+)
- [ ] Proxmox cluster
- [ ] Jellyfin
- [ ] Backup Kopia

## 📝 Documentation

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Architecture générale
- **[docs/ACCESS-ARCHITECTURE.md](docs/ACCESS-ARCHITECTURE.md)** - Méthodes d'accès (Tunnel/Direct/VPN)
- **[docs/DEPLOYMENT-ARCHITECTURE.md](docs/DEPLOYMENT-ARCHITECTURE.md)** - Guide déploiement détaillé avec dépendances
- **[doppler.yaml](doppler.yaml)** - Configuration secrets
- **[terraform/oracle-cloud/README.md](../terraform/oracle-cloud/README.md)** - Setup Terraform

## 🆘 Support & Dépannage

### Problèmes courants

**Omni inaccessible après config auth:**
```bash
# Sur VM Hub, réinitialiser Omni:
sudo docker exec -it omni rm /data/omni.db
sudo docker restart omni
```

**Secrets ne se synchronisent pas:**
```bash
# Vérifier External Secrets Operator
kubectl logs -n flux-system deployment/external-secrets

# Fallback manuel si besoin
kubectl create secret generic fallback-secret \
  --from-literal=key=value -n namespace
```

**Cluster K8s inaccessible:**
```bash
# Vérifier via Omni
omnictl cluster status -c oci-hub

# Ou re-générer kubeconfig
omnictl kubeconfig -c oci-hub > ~/.kube/config
```

### Commandes utiles

```bash
# Status Doppler
doppler secrets -p infrastructure

# Status Tailscale (sur VM Hub)
ssh ubuntu@$(terraform -chdir=terraform/oracle-cloud output -raw hub_public_ip) "sudo tailscale status"

# Logs Flux
flux logs --level=error

# Vérifier certificats
kubectl get certificates -A
```

## ⚠️ Bonnes Pratiques

1. **Jamais** configurer Omni avec Authentik avant qu'Authentik soit déployé
2. **Toujours** garder un accès admin local à Omni (backup)
3. **Ne jamais** commiter de secrets dans Git
4. **Toujours** utiliser Doppler pour les secrets sensibles
5. **Tester** chaque phase avant de passer à la suivante

## 🎯 Prochaines Étapes

1. ✅ Lire [docs/DEPLOYMENT-ARCHITECTURE.md](docs/DEPLOYMENT-ARCHITECTURE.md)
2. ✅ Exécuter `./scripts/setup-doppler.sh`
3. ✅ Suivre le guide Phase par Phase
4. ⭐ Star ce repo si utile!

---

**Note**: Ce projet est en construction active. Des changements peuvent survenir.
