# Déploiements GitHub Actions

## Environnements

| Environnement | Usage | Déclencheur |
|---------------|--------|-------------|
| **development** | Tests, plan Terraform uniquement | PR sur `main`, push sur `develop`, ou `workflow_dispatch` avec action = plan |
| **production** | Apply Terraform (infra réelle) | Push sur `main`, ou `workflow_dispatch` avec action = apply et environment = production |

## Architecture des secrets

Les **secrets applicatifs** (Cloudflare API token, DB passwords, SSH keys, etc.) sont stockés dans **OCI Vault** et récupérés automatiquement par les workflows via l'action `.github/actions/oci-vault-secrets`.

Les **secrets d'authentification OCI** (session token, private key, etc.) restent dans **GitHub Secrets** car nécessaires pour accéder au Vault.

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Actions Workflow                      │
├─────────────────────────────────────────────────────────────────┤
│  1. Auth OCI (GitHub Secrets)                                    │
│     └─> OCI_SESSION_TOKEN, OCI_SESSION_PRIVATE_KEY, etc.        │
│                                                                   │
│  2. Fetch secrets from OCI Vault                                 │
│     └─> cloudflare_api_token, omni_db_password, ssh_key, etc.   │
│                                                                   │
│  3. Use secrets in workflow steps                                │
└─────────────────────────────────────────────────────────────────┘
```

**Secrets dans OCI Vault :**

| Secret OCI Vault | Usage |
|------------------|-------|
| `homelab-cloudflare-api-token` | Token API Cloudflare (Zone → Edit) |
| `homelab-tfstate-dev-token` | GitHub PAT pour TFstate.dev lock |
| `homelab-omni-db-user` | Utilisateur PostgreSQL Omni |
| `homelab-omni-db-password` | Mot de passe PostgreSQL Omni |
| `homelab-omni-db-name` | Nom de la base Omni |
| `homelab-oci-mgmt-ssh-private-key` | Clé privée SSH pour VM management |

**Peupler les secrets OCI Vault :**

```bash
# Lister l'état des secrets
./scripts/oci-vault-secrets-setup.sh --list

# Mode interactif pour mettre à jour les valeurs
./scripts/oci-vault-secrets-setup.sh
```

## Guide pas à pas (recréer tous les secrets)

Si tu dois tout recréer : **[docs-site/docs/runbooks/rotate-secrets.md](../docs-site/docs/runbooks/rotate-secrets.md)** (section « Recréer tous les secrets ») — étapes 1 à 4 dans l’ordre (GitHub PAT, Cloudflare, OCI session + compartment/namespace/SSH, OCI Management).

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
./scripts/gh-secrets-setup.sh
```

Pour **OCI**, l'authentification en CI utilise un **session token** (court terme) au lieu d'une clé API longue durée. Générer le token puis pousser les secrets :

```bash
./scripts/oci-session-auth-to-gh.sh
# Ou avec options : --region eu-paris-1 --exp-time 60
```

Une fenêtre navigateur s'ouvre pour te connecter à OCI ; le script envoie ensuite les secrets OCI dans le dépôt. **À refaire** quand le token expire (par défaut 60 min, réglable 5–60). Ensuite, pour compartment / namespace / clé SSH : `./scripts/gh-secrets-setup.sh` (section OCI).

Le script `gh-secrets-setup.sh` crée les environnements **development** et **production** s’ils n’existent pas, puis configure les autres secrets (interactif ou via variables d’environnement).

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

L’authentification OCI en CI utilise un **session token** (court terme) au lieu d’une clé API. Les secrets liés au token sont définis par `./scripts/oci-session-auth-to-gh.sh` ; les autres restent à configurer (manuel ou `gh-secrets-setup.sh`).

**Définis par `oci-session-auth-to-gh.sh`** (à régénérer quand le token expire, par défaut 60 min) :

| Secret | Description |
|--------|-------------|
| `OCI_SESSION_TOKEN` | Token de session OCI (contenu du fichier token) |
| `OCI_SESSION_PRIVATE_KEY` | Clé privée PEM de la session |
| `OCI_CLI_USER` | User OCID |
| `OCI_CLI_TENANCY` | Tenancy OCID |
| `OCI_CLI_FINGERPRINT` | Empreinte de la clé de session |
| `OCI_CLI_REGION` | Ex. `eu-paris-1` |

**À définir à part** (manuel ou `gh-secrets-setup.sh`) :

| Secret | Description |
|--------|-------------|
| `OCI_COMPARTMENT_ID` | Compartment OCID |
| `SSH_PUBLIC_KEY` | Clé publique SSH pour les VMs |
| `OCI_OBJECT_STORAGE_NAMESPACE` | Namespace Object Storage du tenancy (backend state). En CI injecté dans `backend.tf` ; en local remplacer `YOUR_TENANCY_NAMESPACE` dans `backend.tf` (voir [terraform/oracle-cloud/README.md](../terraform/oracle-cloud/README.md)). |

### 3b. OCI Management Stack (workflow Deploy OCI Management Stack)

Pour déployer Omni + PostgreSQL sur la VM management depuis la CI (push sur `docker/oci-mgmt/` ou run manuel) :

| Secret | Description |
|--------|-------------|
| `OCI_MGMT_SSH_PRIVATE_KEY` | Clé privée SSH pour se connecter à la VM management (même paire que `SSH_PUBLIC_KEY` utilisée par Terraform). |
| `OMNI_DB_USER` | Utilisateur PostgreSQL Omni (ex. `omni`). |
| `OMNI_DB_PASSWORD` | Mot de passe PostgreSQL Omni (fort, stocké uniquement dans GitHub Secrets). |
| `OMNI_DB_NAME` | Nom de la base Omni (ex. `omni`). |

Le workflow lit l’IP de la VM depuis le state Terraform (job **Get management VM IP**), puis SSH + `docker compose up -d` sur la VM.

## Pourquoi les déploiements échouent ?

Les déploiements "Failed" viennent en général d’un **échec du job** (pas seulement de l’environnement). Vérifier l’onglet **Actions** → le workflow concerné → le job en erreur.

### Causes fréquentes

1. **Secrets manquants**
   - **Cloudflare** : `CLOUDFLARE_API_TOKEN` (Settings → Secrets and variables → Actions).
   - **OCI** : `OCI_SESSION_TOKEN`, `OCI_SESSION_PRIVATE_KEY`, `OCI_CLI_USER`, `OCI_CLI_TENANCY`, `OCI_CLI_FINGERPRINT`, `OCI_CLI_REGION` (générés par `./scripts/oci-session-auth-to-gh.sh`), puis `OCI_COMPARTMENT_ID`, `SSH_PUBLIC_KEY`, `OCI_OBJECT_STORAGE_NAMESPACE`. Si le token a expiré, relancer `oci-session-auth-to-gh.sh`.
   - **OCI Management Stack** : `OCI_MGMT_SSH_PRIVATE_KEY`, `OMNI_DB_USER`, `OMNI_DB_PASSWORD`, `OMNI_DB_NAME`.
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
## Branches

- **main** : déploiement **production** (apply Cloudflare et OCI sur push si les paths concernés changent).
- **develop** : uniquement **plan** (development), pas d’apply. Utile pour tester des changements Terraform sans toucher à la prod.
