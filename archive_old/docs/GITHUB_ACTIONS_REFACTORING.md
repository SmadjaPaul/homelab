# GitHub Actions Refactoring & Authentik Bootstrap Token

## 🎯 Résumé des changements

### 1. Actions réutilisables créées

| Action | Description | Utilisation |
|--------|-------------|-------------|
| `setup-oci-cli` | Configure OCI CLI avec les credentials Doppler | Réutilisé dans tous les jobs |
| `terraform-oci` | Setup Terraform + injection namespace OCI | Jobs Terraform |
| `deploy-docker-compose` | Déploie Docker Compose sur la VM OCI | Déploiement services |
| `get-oci-vm-ip` | Récupère l'IP de la VM management | Besoin de l'IP |
| `fetch-doppler` | Fetch secrets Doppler (étendu) | Tous les workflows |

### 2. Workflow généralisé `deploy-stack.yml`

**Avant :** ~290 lignes avec duplication
**Après :** ~180 lignes, actions réutilisables

**Structure en 4 couches :**
1. **Cloudflare** - DNS, Tunnel, Access
2. **OCI** - Infrastructure (VMs, network)
3. **oci-mgmt** - Déploiement Docker Compose
4. **Authentik** - Configuration Terraform (AUTOMATIQUE !)

## 🔑 Solution : Bootstrap Token Authentik

### Le problème
Avant : Création manuelle du token API Authentik après le premier déploiement

### La solution
Utilisation de **`AUTHENTIK_BOOTSTRAP_TOKEN`** :

```yaml
# Dans docker-compose.yml
create_service_account = true
token_identifier       = "terraform-ci"
superuser              = true
```

**Comment ça marche :**
1. Authentik démarre avec `AUTHENTIK_BOOTSTRAP_TOKEN` (déjà dans Doppler)
2. Ce token a les permissions superuser
3. Terraform utilise ce token pour s'authentifier
4. Terraform crée un service account dédié + token
5. Le token est output et peut être sauvegardé

### Flux automatique

```
1. Déploiement Docker Compose (Layer 3)
   ├─ Authentik démarre avec bootstrap token
   └─ Attente que l'API soit ready (health check)

2. Configuration Authentik (Layer 4)
   ├─ Terraform s'authentifie avec bootstrap token
   ├─ Crée users, groups, policies
   ├─ Crée service account "terraform-ci"
   └─ Génère token dédié pour CI/CD
```

### Avantages
✅ **Zero étape manuelle** - Tout est automatisé
✅ **Sécurisé** - Bootstrap token dans Doppler (jamais exposé)
✅ **Reproductible** - Même processus à chaque déploiement
✅ **Audit trail** - Actions Terraform tracées

## 📁 Structure des Actions

```
.github/
├── actions/
│   ├── fetch-doppler/
│   │   └── action.yml          # Fetch secrets Doppler
│   ├── setup-oci-cli/
│   │   └── action.yml          # Configure OCI CLI
│   ├── terraform-oci/
│   │   └── action.yml          # Terraform + OCI backend
│   ├── deploy-docker-compose/
│   │   └── action.yml          # Déploiement Docker
│   ├── get-oci-vm-ip/
│   │   └── action.yml          # Récupère IP VM
│   ├── run-ansible/
│   │   └── action.yml          # (existant)
│   ├── terraform-apply/
│   │   └── action.yml          # (existant - générique)
│   ├── terraform-plan/
│   │   └── action.yml          # (existant - générique)
│   └── terraform-validate/
│       └── action.yml          # (existant - générique)
└── workflows/
    ├── deploy-stack.yml        # Workflow principal (généralisé)
    └── manual-deploy.yml       # Déploiement manuel
```

## 🚀 Utilisation

### Déploiement complet (automatique)
```bash
gh workflow run deploy-stack.yml
```

### Déploiement manuel (étape par étape)
```bash
# 1. Cloudflare uniquement
gh workflow run manual-deploy.yml -f layer=cloudflare

# 2. OCI uniquement
gh workflow run manual-deploy.yml -f layer=oci

# 3. Docker uniquement
gh workflow run manual-deploy.yml -f layer=oci_mgmt

# 4. Authentik uniquement
gh workflow run manual-deploy.yml -f layer=authentik
```

## 📋 Secrets Doppler requis

### Infrastructure
```bash
# Cloudflare
CLOUDFLARE_API_TOKEN
CLOUDFLARE_ZONE_ID
CLOUDFLARE_ACCOUNT_ID
CLOUDFLARE_TUNNEL_ID
CLOUDFLARE_TUNNEL_SECRET
DOMAIN

# OCI
OCI_CLI_USER
OCI_CLI_FINGERPRINT
OCI_CLI_TENANCY
OCI_CLI_REGION
OCI_CLI_KEY_CONTENT
OCI_COMPARTMENT_ID
OCI_OBJECT_STORAGE_NAMESPACE

# SSH
SSH_PUBLIC_KEY
SSH_PRIVATE_KEY

# Authentik (générés automatiquement)
AUTHENTIK_SECRET_KEY
AUTHENTIK_BOOTSTRAP_TOKEN      # ← Utilisé par Terraform
AUTHENTIK_BOOTSTRAP_PASSWORD
AUTHENTIK_POSTGRES_HOST        # ← Aiven
AUTHENTIK_POSTGRES_PORT
AUTHENTIK_POSTGRES_NAME
AUTHENTIK_POSTGRES_USER
AUTHENTIK_POSTGRES_PASSWORD
```

## 🔧 Génération des secrets Authentik

```bash
# Dans Doppler (infrastructure project)
doppler secrets set AUTHENTIK_SECRET_KEY "$(openssl rand -base64 60)" -c prd
doppler secrets set AUTHENTIK_BOOTSTRAP_TOKEN "$(openssl rand -hex 32)" -c prd
doppler secrets set AUTHENTIK_BOOTSTRAP_PASSWORD "$(openssl rand -base64 32)" -c prd
```

## 🔄 Ordre de déploiement

```
Layer 1: Cloudflare
    └─ DNS records, Tunnel, Access policies

Layer 2: OCI Infrastructure
    └─ VMs, VCN, Security Groups

Layer 3: Docker Compose (oci-mgmt)
    └─ Traefik, Authentik, Prometheus, Blocky
    └─ Authentik démarre avec bootstrap token

Layer 4: Authentik Configuration
    └─ Terraform utilise bootstrap token
    └─ Crée configuration (users, groups, policies)
    └─ Crée service account CI/CD
```

## 🎉 Résultat

**Avant :**
- 290 lignes de code dupliqué
- Étapes manuelles pour créer token Authentik
- Maintenance complexe

**Après :**
- 180 lignes avec actions réutilisables
- 100% automatisé (bootstrap token)
- Facile à maintenir et étendre

## 📝 Notes importantes

1. **Bootstrap Token** : Est utilisé une seule fois au premier déploiement, puis Terraform crée son propre token

2. **Health Check** : Le workflow attend que l'API Authentik soit prête avant de lancer Terraform

3. **Idempotence** : Le workflow peut être relancé sans problème (Terraform gère les changements)

4. **Erreurs** : `continue-on-error: true` sur l'étape Authentik permet de continuer même si l'API n'est pas encore prête

## 🔮 Améliorations futures

- [ ] Action `setup-kubectl` pour Kubernetes
- [ ] Action `deploy-helm` pour charts Helm
- [ ] Workflow `destroy-stack.yml` pour cleanup
- [ ] Tests automatisés des actions
