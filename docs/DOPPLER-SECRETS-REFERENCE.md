# Référentiel de Secrets Doppler - Intégration Terraform

Ce document décrit comment les secrets sont gérés entre Doppler et Terraform.

## 🔄 Flux de Données

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DOPPLER                                         │
│                         (Source de vérité)                                   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Projet: homelab (config: prd)                                      │   │
│  │                                                                      │   │
│  │  Secrets en INPUT (fournis par vous):                               │   │
│  │  ├── OCI_CLI_* (credentials Oracle Cloud)                          │   │
│  │  ├── CLOUDFLARE_API_TOKEN, ZONE_ID, ACCOUNT_ID                     │   │
│  │  ├── AUTHENTIK_BOOTSTRAP_TOKEN (temporaire)                        │   │
│  │  ├── AUTHENTIK_SECRET_KEY, POSTGRES_*                             │   │
│  │  ├── SSH_PUBLIC_KEY, SSH_PRIVATE_KEY                               │   │
│  │  └── ...                                                           │   │
│  │                                                                      │   │
│  │  Secrets en OUTPUT (générés/mis à jour par Terraform):             │   │
│  │  ├── CLOUDFLARE_TUNNEL_ID                                          │   │
│  │  ├── CLOUDFLARE_TUNNEL_SECRET                                      │   │
│  │  ├── CLOUDFLARE_TUNNEL_TOKEN                                       │   │
│  │  ├── AUTHENTIK_TOKEN                                               │   │
│  │  ├── AUTHENTIK_TOKEN_TERRAFORM_CI                                  │   │
│  │  ├── AUTHENTIK_TOKEN_* (service accounts)                          │   │
│  │  └── AUTHENTIK_PASSWORD_ROTATION_TRIGGER                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
                    ▼               ▼               ▼
        ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
        │ terraform/    │ │ terraform/    │ │ terraform/    │
        │ cloudflare    │ │ oracle-cloud  │ │ authentik     │
        └───────────────┘ └───────────────┘ └───────────────┘
```

## 📋 Liste Complète des Secrets

### Secrets INPUT (à définir manuellement dans Doppler)

#### Cloudflare (`terraform/cloudflare`)
```yaml
DOMAIN: "smadja.dev"                           # Domaine racine
CLOUDFLARE_ZONE_ID: "<zone-id>"                # Zone ID Cloudflare
CLOUDFLARE_API_TOKEN: "<api-token>"            # Token API Cloudflare
CLOUDFLARE_ACCOUNT_ID: "<account-id>"          # Account ID
CLOUDFLARE_TUNNEL_ID: ""                        # Sera rempli par Terraform
CLOUDFLARE_TUNNEL_SECRET: ""                    # Sera rempli par Terraform
CLOUDFLARE_TUNNEL_TOKEN: ""                     # Sera rempli par Terraform
ACME_EMAIL: "smadja-paul@protonmail.com"       # Email Let's Encrypt
ALERT_EMAIL: "smadja-paul@protonmail.com"      # Email pour alertes
ENABLE_ZONE_SETTINGS: "true"                    # Activer paramètres zone
ENABLE_GEO_RESTRICTION: "false"                 # Activer restriction géo
ENABLE_API_SKIP_CHALLENGE: "true"               # Skip challenge pour API
```

#### Oracle Cloud (`terraform/oracle-cloud`)
```yaml
# ATTENTION: Utilisez ces noms exacts (correspondent à votre Doppler)
OCI_CLI_USER: "ocid1.user.oc1..xxxx"           # OCID utilisateur OCI
OCI_CLI_FINGERPRINT: "xx:xx:xx:xx:xx:xx:xx"    # Fingerprint API key
OCI_CLI_TENANCY: "ocid1.tenancy.oc1..xxxx"     # OCID tenancy (NOTE: pas OCI_TENANCY_OCID)
OCI_CLI_REGION: "eu-paris-1"                   # Région OCI
OCI_CLI_KEY_CONTENT: "-----BEGIN RSA..."       # Clé privée API (multiline)
OCI_COMPARTMENT_ID: "ocid1.compartment..."     # OCID compartment
OCI_OBJECT_STORAGE_NAMESPACE: "axnvxxurxefp"   # Namespace Object Storage
SSH_PUBLIC_KEY: "ssh-rsa AAAA..."              # Clé SSH publique
SSH_PRIVATE_KEY: "-----BEGIN OPENSSH..."       # Clé SSH privée
```

#### Authentik (`terraform/authentik`)
```yaml
AUTHENTIK_URL: "https://auth.smadja.dev"       # URL publique Authentik
AUTHENTIK_TOKEN: ""                             # Sera rempli par Terraform
AUTHENTIK_BOOTSTRAP_PASSWORD: "<password>"     # Mot de passe initial admin
AUTHENTIK_BOOTSTRAP_TOKEN: "<token>"           # Token temporaire bootstrap
AUTHENTIK_SECRET_KEY: "<base64-60-chars>"      # Clé secrète (openssl rand -base64 60)
# PostgreSQL
AUTHENTIK_POSTGRES_HOST: "authentik-postgresql"
AUTHENTIK_POSTGRES_NAME: "authentik"
AUTHENTIK_POSTGRES_USER: "authentik"
AUTHENTIK_POSTGRES_PASSWORD: "<password>"
AUTHENTIK_POSTGRES_PORT: "5432"
```

#### Tailscale (pour GitHub Actions)
```yaml
TS_OAUTH_CLIENT_ID: "<oauth-client-id>"        # OAuth Client ID Tailscale
TS_OAUTH_SECRET: "<oauth-secret>"              # OAuth Secret Tailscale
```

### Secrets OUTPUT (automatiquement mis à jour par Terraform)

#### Cloudflare (mise à jour automatique)
```yaml
CLOUDFLARE_TUNNEL_ID: "<generated-by-terraform>"
CLOUDFLARE_TUNNEL_SECRET: "<generated-by-terraform>"
CLOUDFLARE_TUNNEL_TOKEN: '{"AccountTag":"...","TunnelID":"...","TunnelSecret":"..."}'
```

#### Authentik (mise à jour automatique)
```yaml
AUTHENTIK_TOKEN: "<token-generated>"                    # Token principal
AUTHENTIK_TOKEN_TERRAFORM_CI: "<token-generated>"       # Token CI/CD
AUTHENTIK_TOKEN_TERRAFORM_SERVICE: "<token-generated>"  # Service account
AUTHENTIK_TOKEN_GITHUB_ACTIONS: "<token-generated>"     # GitHub Actions
AUTHENTIK_TOKEN_EXTERNAL_DNS: "<token-generated>"       # External DNS
AUTHENTIK_PASSWORD_ROTATION_TRIGGER: "v1"               # Version rotation
```

## 🔧 Configuration dans Terraform

### 1. Récupération des secrets (INPUT)

Tous les modules Terraform utilisent ce pattern :

```hcl
# Récupérer les secrets depuis Doppler
data "doppler_secrets" "this" {
  project = "homelab"
  config  = "prd"
}

# Utiliser un secret
provider "cloudflare" {
  api_token = data.doppler_secrets.this.map.CLOUDFLARE_API_TOKEN
}
```

### 2. Mise à jour des secrets (OUTPUT)

Quand Terraform génère de nouvelles valeurs, il les pousse vers Doppler :

```hcl
# Exemple: Cloudflare Tunnel
resource "doppler_secret" "tunnel_id" {
  project = "homelab"
  config  = "prd"
  name    = "CLOUDFLARE_TUNNEL_ID"
  value   = cloudflare_tunnel.this.id
}

# Exemple: Authentik Token
resource "doppler_secret" "authentik_token" {
  project = "homelab"
  config  = "prd"
  name    = "AUTHENTIK_TOKEN"
  value   = authentik_token.terraform_ci.key
}
```

## 🚀 Workflow Complet

### Premier déploiement (Initialisation)

```bash
# 1. Ajouter les secrets INPUT dans Doppler (interface web ou CLI)
doppler secrets set OCI_CLI_USER="ocid1.user.oc1..xxxx" -p homelab -c prd
doppler secrets set OCI_CLI_KEY_CONTENT="-----BEGIN..." -p homelab -c prd
doppler secrets set AUTHENTIK_SECRET_KEY="$(openssl rand -base64 60)" -p homelab -c prd
# ... etc pour tous les secrets INPUT

# 2. Lancer Terraform
export DOPPLER_TOKEN=$(doppler configs tokens create prd temp-token -p homelab --plain)

# Oracle Cloud (crée l'infrastructure)
cd terraform/oracle-cloud
terraform init
terraform apply

# Cloudflare (crée le tunnel, met à jour Doppler automatiquement)
cd ../cloudflare
terraform init
terraform apply

# Authentik (crée les tokens, met à jour Doppler automatiquement)
cd ../authentik
terraform init
terraform apply

# 3. Vérifier les secrets OUTPUT dans Doppler
doppler secrets -p homelab -c prd
```

### Mise à jour (Rotation)

```bash
# Exemple: Rotation des tokens Authentik
cd terraform/authentik
terraform apply -var="password_rotation_trigger=v2"

# Les nouveaux tokens sont automatiquement mis à jour dans Doppler
# Vérification:
doppler secrets get AUTHENTIK_TOKEN -p homelab -c prd
```

## 📁 Fichiers Terraform Concernés

### Cloudflare (`terraform/cloudflare/`)
- **main.tf** : Crée les `doppler_secret` pour TUNNEL_ID, TUNNEL_SECRET, TUNNEL_TOKEN
- **modules/global_config/** : Récupère tous les secrets depuis Doppler

### Authentik (`terraform/authentik/`)
- **main.tf** : Crée les `doppler_secret` pour AUTHENTIK_TOKEN, AUTHENTIK_TOKEN_TERRAFORM_CI, rotation_trigger
- **modules/service-accounts/** : Crée des `doppler_secret` pour chaque service account
- **provider.tf** : Configure le provider avec AUTHENTIK_URL et AUTHENTIK_TOKEN depuis Doppler

### Oracle Cloud (`terraform/oracle-cloud/`)
- **main.tf** : Récupère les secrets OCI depuis Doppler avec fallback sur les variables
- Pas de mise à jour Doppler (les secrets sont des inputs, pas des outputs)

## ⚠️ Points d'Attention

### 1. Ordre de Déploiement
```
1. Oracle Cloud (besoin des secrets OCI)
2. Cloudflare (génère les secrets de tunnel → Doppler)
3. Authentik (besoin du tunnel fonctionnel + génère les tokens → Doppler)
```

### 2. Tokens Doppler pour CI/CD

Pour GitHub Actions, créez un token Doppler avec accès au projet `homelab` :

```bash
# Créer un token de service
doppler configs tokens create prd github-actions-token -p homelab --plain

# Stocker dans GitHub Secrets
# Name: DOPPLER_SERVICE_TOKEN
# Value: <token-généré>
```

### 3. Erreur 401-NotAuthenticated (Oracle Cloud)

Si vous obtenez cette erreur, les credentials OCI ne sont pas correctement transmis :

**Solution rapide - Utiliser les variables d'environnement :**
```bash
# Exportez les credentials directement (remplacez par vos valeurs)
export OCI_CLI_TENANCY="ocid1.tenancy.oc1..aaaaaaaaxxxxxxxxxxx"
export OCI_CLI_USER="ocid1.user.oc1..aaaaaaaaxxxxxxxxxxx"
export OCI_CLI_FINGERPRINT="xx:xx:xx:xx:xx:xx:xx"
export OCI_CLI_KEY_CONTENT="-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA2Z3qX2Z3qX2Z3qX2Z3qX2Z3qX2Z3qX2Z3qX2Z3qX2Z3qX2Z3q
...
-----END RSA PRIVATE KEY-----"

# Puis lancez Terraform
cd terraform/oracle-cloud
terraform plan
```

**Vérification :**
```bash
# Utiliser le script de test
./test-credentials.sh

# Ou vérifier manuellement
echo "OCI_CLI_TENANCY: ${OCI_CLI_TENANCY:0:30}..."
echo "OCI_CLI_USER: ${OCI_CLI_USER:0:30}..."
echo "OCI_CLI_FINGERPRINT: $OCI_CLI_FINGERPRINT"
```

### 4. Gestion des Erreurs "Missing map element"

Si Terraform échoue avec "Missing map element", cela signifie qu'un secret n'existe pas dans Doppler :

```bash
# Vérifier les secrets manquants
doppler secrets -p homelab -c prd

# Ajouter le secret manquant
doppler secrets set NOM_DU_SECRET="valeur" -p homelab -c prd
```

### 5. Variables d'Environnement Fallback

Si un secret Doppler n'existe pas, Terraform peut utiliser des variables d'environnement (configuré dans oracle-cloud/main.tf) :

```bash
export OCI_CLI_USER="ocid1.user.oc1..xxxx"
export OCI_CLI_FINGERPRINT="xx:xx:xx:xx"
export OCI_CLI_TENANCY="ocid1.tenancy.oc1..xxxx"
export OCI_CLI_KEY_CONTENT="-----BEGIN RSA..."
terraform apply
```

## 📊 Tableau de Bord des Secrets

| Secret | Type | Projet | Défini par | Utilisé par | Auto-update |
|--------|------|--------|------------|-------------|-------------|
| OCI_CLI_USER | INPUT | homelab | Manuel | oracle-cloud | ❌ |
| OCI_CLI_TENANCY | INPUT | homelab | Manuel | oracle-cloud | ❌ |
| OCI_CLI_FINGERPRINT | INPUT | homelab | Manuel | oracle-cloud | ❌ |
| OCI_CLI_KEY_CONTENT | INPUT | homelab | Manuel | oracle-cloud | ❌ |
| CLOUDFLARE_API_TOKEN | INPUT | homelab | Manuel | cloudflare | ❌ |
| CLOUDFLARE_TUNNEL_ID | OUTPUT | homelab | Terraform | cloudflare, kubernetes | ✅ |
| CLOUDFLARE_TUNNEL_SECRET | OUTPUT | homelab | Terraform | kubernetes | ✅ |
| AUTHENTIK_TOKEN | OUTPUT | homelab | Terraform | authentik, apps | ✅ |
| AUTHENTIK_TOKEN_TERRAFORM_CI | OUTPUT | homelab | Terraform | authentik, ci/cd | ✅ |
| AUTHENTIK_SECRET_KEY | INPUT | homelab | Manuel | kubernetes | ❌ |

## 🔍 Commandes Utiles

```bash
# Lister tous les secrets d'un projet
doppler secrets -p homelab -c prd

# Obtenir la valeur d'un secret
doppler secrets get AUTHENTIK_TOKEN -p homelab -c prd --plain

# Vérifier si un secret existe
doppler secrets get NOM_SECRET -p homelab -c prd 2>&1 | grep -q "not found" && echo "Manquant" || echo "Existe"

# Supprimer un secret
doppler secrets delete NOM_SECRET -p homelab -c prd

# Voir l'historique des modifications
doppler activity -p homelab -c prd
```

## 📚 Références

- [Doppler CLI Documentation](https://docs.doppler.com/docs/cli)
- [Doppler Terraform Provider](https://registry.terraform.io/providers/DopplerHQ/doppler/latest/docs)
- [Fichier doppler.yaml](/doppler.yaml)
