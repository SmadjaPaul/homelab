# Déploiements GitHub Actions

## Environnements

| Environnement | Usage | Déclencheur |
|---------------|--------|-------------|
| **development** | Tests, plan Terraform uniquement | PR sur `main`, push sur `develop`, ou `workflow_dispatch` avec action = plan |
| **production** | Apply Terraform (infra réelle) | Push sur `main`, ou `workflow_dispatch` avec action = apply et environment = production |

## Créer les environnements et les secrets (avec gh CLI)

Depuis la racine du repo, avec [gh](https://cli.github.com/) installé et authentifié (`gh auth login`) :

```bash
# Créer les environnements (development, production) puis configurer tous les secrets
./scripts/gh-secrets-setup.sh

# Uniquement TFstate + Cloudflare (pour débloquer le lock Terraform)
./scripts/gh-secrets-setup.sh --minimal

# En passant les valeurs par variables d'environnement (évite de taper)
export TFSTATE_DEV_TOKEN=ghp_xxxx
export CLOUDFLARE_API_TOKEN=xxxx
export OCI_CLI_KEY_FILE=~/.oci/oci_api_key.pem   # chemin vers la clé PEM
./scripts/gh-secrets-setup.sh
```

Le script crée les environnements **development** et **production** s’ils n’existent pas, puis configure les secrets (interactif ou via variables d’environnement).

## Créer les environnements à la main (sans gh)

1. **Settings** du dépôt → **Environments**
2. Créer deux environnements : `development`, `production`
3. **Optionnel** : sur `production`, ajouter des **Protection rules** (ex. "Required reviewers")

Si les environnements n’existent pas, GitHub les crée au premier run qui les utilise.

## Secrets obligatoires (TFstate.dev + providers)

### 1. TFSTATE_DEV_TOKEN (état Terraform et lock)

L’erreur **"Error acquiring the state lock" / "HTTP remote state endpoint invalid auth"** vient du backend TFstate.dev : le `GITHUB_TOKEN` automatique des Actions ne suffit pas pour le lock. Il faut un **Personal Access Token (PAT)** et le mettre dans un secret.

**Créer le PAT :**

1. GitHub → **Settings** (ton profil) → **Developer settings** → **Personal access tokens** → **Tokens (classic)** ou **Fine-grained tokens**.
2. **New token** :
   - **Classic** : cocher au minimum `repo` (Full control of private repositories).
   - **Fine-grained** : ce dépôt, permission **Contents** = Read and write.
3. Générer et **copier le token** (tu ne le reverras plus).

**Ajouter le secret au dépôt :**

1. Dans le dépôt : **Settings** → **Secrets and variables** → **Actions**.
2. **New repository secret** :
   - Name : `TFSTATE_DEV_TOKEN`
   - Value : le PAT collé.
3. Enregistrer.

Les workflows Cloudflare et OCI utilisent `TFSTATE_DEV_TOKEN` pour `terraform init` (état + lock). Sans ce secret, le lock TFstate.dev échoue.

### 2. Cloudflare

| Secret | Description |
|--------|-------------|
| `CLOUDFLARE_API_TOKEN` | Token API Cloudflare (Zone → Edit, API Tokens). |

### 3. Oracle Cloud (pour le workflow OCI)

| Secret | Description |
|--------|-------------|
| `OCI_CLI_USER` | User OCID (`ocid1.user.oc1..xxxxx`) |
| `OCI_CLI_TENANCY` | Tenancy OCID |
| `OCI_CLI_FINGERPRINT` | Empreinte de la clé API |
| `OCI_CLI_KEY_CONTENT` | Contenu de la clé privée PEM (tout le fichier) |
| `OCI_CLI_REGION` | Ex. `eu-paris-1` |
| `OCI_COMPARTMENT_ID` | Compartment OCID |
| `SSH_PUBLIC_KEY` | Clé publique SSH pour les VMs |

### 3b. OCI Management Stack (workflow Deploy OCI Management Stack)

Pour déployer Omni + PostgreSQL sur la VM management depuis la CI (push sur `docker/oci-mgmt/` ou run manuel) :

| Secret | Description |
|--------|-------------|
| `OCI_MGMT_SSH_PRIVATE_KEY` | Clé privée SSH pour se connecter à la VM management (même paire que `SSH_PUBLIC_KEY` utilisée par Terraform). |
| `OMNI_DB_USER` | Utilisateur PostgreSQL Omni (ex. `omni`). |
| `OMNI_DB_PASSWORD` | Mot de passe PostgreSQL Omni (fort, stocké uniquement dans GitHub Secrets). |
| `OMNI_DB_NAME` | Nom de la base Omni (ex. `omni`). |

Le workflow lit l’IP de la VM depuis le state Terraform (job **Get management VM IP**), puis SSH + `docker compose up -d` sur la VM.

### 4. OVHcloud (pour le workflow OVHcloud – Object Storage S3)

| Secret | Description |
|--------|-------------|
| `OVH_APPLICATION_KEY` | Clé application API OVH ([createToken](https://eu.api.ovh.com/createToken/)) |
| `OVH_APPLICATION_SECRET` | Secret de l’application API OVH |
| `OVH_CONSUMER_KEY` | Consumer key OVH |
| `OVH_CLOUD_PROJECT_ID` | ID du projet Public Cloud (service_name, UUID) |
| `OVH_BUDGET_ALERT_EMAIL` | Email pour recevoir l’alerte budget à 1 € (ou variable `OVH_BUDGET_ALERT_EMAIL`) |
| `OVH_S3_ACCESS_KEY` | *(Optionnel)* Access key S3 (après 1er apply : sortie `velero_s3_credentials`) |
| `OVH_S3_SECRET_KEY` | *(Optionnel)* Secret key S3 (après 1er apply) – nécessaire pour que le 2e apply crée le bucket |

## Pourquoi les déploiements échouent ?

Les déploiements "Failed" viennent en général d’un **échec du job** (pas seulement de l’environnement). Vérifier l’onglet **Actions** → le workflow concerné → le job en erreur.

### Causes fréquentes

1. **Secrets manquants**
   - **Cloudflare** : `CLOUDFLARE_API_TOKEN` (Settings → Secrets and variables → Actions).
   - **OCI** : `OCI_CLI_USER`, `OCI_CLI_TENANCY`, `OCI_CLI_FINGERPRINT`, `OCI_CLI_KEY_CONTENT`, `OCI_CLI_REGION`, `OCI_COMPARTMENT_ID`, `SSH_PUBLIC_KEY`.
   - **OCI Management Stack** : `OCI_MGMT_SSH_PRIVATE_KEY`, `OMNI_DB_USER`, `OMNI_DB_PASSWORD`, `OMNI_DB_NAME`.
   - **OVHcloud** : `OVH_APPLICATION_KEY`, `OVH_APPLICATION_SECRET`, `OVH_CONSUMER_KEY`, `OVH_CLOUD_PROJECT_ID` (optionnel pour le bucket : `OVH_S3_ACCESS_KEY`, `OVH_S3_SECRET_KEY` après 1er apply).

2. **Backend Terraform (TFstate.dev) – "invalid auth" / "state lock"**
   - Les workflows utilisent le secret **`TFSTATE_DEV_TOKEN`** (PAT GitHub) pour l’état et le lock. Sans ce secret, tu obtiens "Error acquiring the state lock" / "HTTP remote state endpoint invalid auth".
   - Créer un PAT (voir section **Secrets obligatoires** ci-dessus) et l’enregistrer dans **Settings → Secrets and variables → Actions** sous le nom `TFSTATE_DEV_TOKEN`.

3. **Environment "production" avec approbation**
   - Si **Required reviewers** est activé sur `production`, le job attend une validation. Sans approbation, il peut rester "pending" puis être annulé ou marqué en échec selon la config.

4. **Erreur Terraform**
   - Token Cloudflare invalide ou expiré.
   - Quota OCI dépassé ou erreur API OCI (ex. "Out of capacity").
   - Regarder les logs du step **Terraform Apply** (ou **Terraform Plan**) dans l’exécution du workflow.

## Workflow manuel

- **Cloudflare** : Actions → "Cloudflare Infrastructure" → Run workflow → choisir `plan` (development) ou `apply` (production).
- **OCI** : Actions → "Terraform Oracle Cloud" → Run workflow → choisir `plan` / `apply` / `destroy` et l’environnement cible.
- **OCI Management Stack (Omni)** : Actions → "Deploy OCI Management Stack" → Run workflow. Déploie `docker/oci-mgmt` sur la VM management (IP depuis Terraform state). Déclenché aussi sur push `main` si `docker/oci-mgmt/**` change.
- **OVHcloud** : Actions → "Terraform OVHcloud" → Run workflow. Premier run : user + credential S3 ; ajouter `OVH_S3_ACCESS_KEY` et `OVH_S3_SECRET_KEY` (depuis la sortie Terraform), puis relancer pour créer le bucket.

## Branches

- **main** : déploiement **production** (apply Cloudflare, OCI et OVHcloud sur push si les paths concernés changent).
- **develop** : uniquement **plan** (development), pas d’apply. Utile pour tester des changements Terraform sans toucher à la prod.
