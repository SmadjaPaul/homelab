---
sidebar_position: 2
---

# Configuration des Secrets

Guide complet pour configurer tous les secrets nécessaires au fonctionnement du homelab.

---

## 📋 Checklist Rapide

### GitHub Secrets (authentification OCI)
- [ ] `OCI_CLI_TENANCY` - OCID du tenancy
- [ ] `OCI_CLI_USER` - OCID de l'utilisateur
- [ ] `OCI_CLI_FINGERPRINT` - Empreinte de la clé API
- [ ] `OCI_CLI_REGION` - Région (ex: `eu-paris-1`)
- [ ] `OCI_CLI_KEY_CONTENT` - Contenu de la clé API privée (PEM)
- [ ] `OCI_DOMAIN_URL` - URL du domaine OCI (pour OIDC)
- [ ] `OCI_OIDC_CLIENT_ID` - Client ID OIDC
- [ ] `OCI_OIDC_CLIENT_SECRET` - Client secret OIDC
- [ ] `OCI_COMPARTMENT_ID` - OCID du compartment
- [ ] `OCI_OBJECT_STORAGE_NAMESPACE` - Namespace Object Storage
- [ ] `SSH_PUBLIC_KEY` - **CLÉ PUBLIQUE** SSH (une ligne)
- [ ] `OCI_MGMT_SSH_PRIVATE_KEY` - Clé privée SSH (PEM complet)
- [ ] `GH_TOKEN` - GitHub PAT avec `admin:repo` (optionnel, pour rotation auto)
- [ ] `CLOUDFLARE_API_TOKEN` - Token API Cloudflare

### OCI Vault Secrets (créés par Terraform)
- [ ] `homelab-cloudflare-api-token`
- [ ] `homelab-oci-mgmt-ssh-private-key`
- [ ] `homelab-omni-db-user`
- [ ] `homelab-omni-db-password`
- [ ] `homelab-omni-db-name`

---

## 🔐 Étape 1: Secrets GitHub (Authentification OCI)

### 1.1 Authentification OCI (Session Token)

**Méthode recommandée**: Utiliser le script automatique qui génère un session token OIDC.

```bash
./scripts/oci-session-auth-to-gh.sh
```

Ce script va:
1. Ouvrir un navigateur pour l'authentification OCI
2. Générer un session token
3. Mettre à jour automatiquement les secrets GitHub:
   - `OCI_SESSION_TOKEN`
   - `OCI_SESSION_PRIVATE_KEY`
   - `OCI_CLI_TENANCY`
   - `OCI_CLI_USER`
   - `OCI_CLI_FINGERPRINT`
   - `OCI_CLI_REGION`
   - `OCI_DOMAIN_URL`
   - `OCI_OIDC_CLIENT_ID`
   - `OCI_OIDC_CLIENT_SECRET`

**Alternative manuelle**: Configurer OCI CLI et extraire les valeurs:
```bash
oci setup config
# Puis lire ~/.oci/config et mettre à jour les secrets manuellement
```

### 1.2 Clés API OCI (si session token non utilisé)

Si tu préfères utiliser les clés API classiques:

```bash
# Générer une clé API
oci setup keys

# Mettre à jour le secret OCI_CLI_KEY_CONTENT
gh secret set OCI_CLI_KEY_CONTENT < ~/.oci/oci_api_key.pem
```

### 1.3 Compartment ID et Namespace

```bash
# Compartment ID: OCI Console → Identity → Compartments → Copier OCID
gh secret set OCI_COMPARTMENT_ID --body "ocid1.compartment.oc1..xxxxx"

# Object Storage Namespace: OCI Console → Object Storage → Namespace (en haut)
gh secret set OCI_OBJECT_STORAGE_NAMESPACE --body "votre-namespace"
```

### 1.4 Clés SSH

**Option A: Générer une nouvelle paire (recommandé)**

```bash
./scripts/fix-ssh-secret.sh --generate-new
```

**Option B: Utiliser une clé existante**

```bash
# Vérifier que c'est bien une clé PUBLIQUE
head -1 ~/.ssh/id_ed25519.pub
# Doit commencer par "ssh-ed25519" ou "ssh-rsa"

# Mettre à jour les secrets
gh secret set SSH_PUBLIC_KEY < ~/.ssh/id_ed25519.pub
gh secret set OCI_MGMT_SSH_PRIVATE_KEY < ~/.ssh/id_ed25519
```

**⚠️ Important**:
- `SSH_PUBLIC_KEY` doit être la **clé publique** (une ligne, commence par `ssh-`)
- `OCI_MGMT_SSH_PRIVATE_KEY` doit être la **clé privée** (PEM complet avec `-----BEGIN`)

### 1.5 Cloudflare API Token

```bash
# Créer un token: Cloudflare Dashboard → My Profile → API Tokens → Create Token
# Permissions: Zone → Edit (pour DNS)
gh secret set CLOUDFLARE_API_TOKEN --body "votre-token"
```

### 1.6 GitHub PAT (optionnel, pour rotation automatique)

```bash
# Créer un PAT: GitHub → Settings → Developer settings → Personal access tokens
# Scopes: admin:repo ou repository → Secrets: write
gh secret set GH_TOKEN --body "ghp_xxxxx"
```

---

## 🗄️ Étape 2: Créer les Ressources OCI (Terraform)

Les secrets OCI Vault sont créés automatiquement par Terraform lors du premier `terraform apply`.

### 2.1 Appliquer Terraform

**Via GitHub Actions** (recommandé):
1. Actions → "Terraform Oracle Cloud" → Run workflow
2. Action: `apply`
3. Environment: `production`

**Localement**:
```bash
cd terraform/oracle-cloud
terraform init
terraform apply
```

### 2.2 Vérifier les Secrets Créés

```bash
# Via Terraform output
terraform output vault_secrets

# Via OCI CLI
oci vault secret list --compartment-id "$OCI_COMPARTMENT_ID" --all
```

---

## 🔄 Étape 3: Peupler les Secrets OCI Vault

Une fois les ressources créées, mettre à jour le contenu des secrets:

### 3.1 Via Script Interactif

```bash
./scripts/oci-vault-secrets-setup.sh
```

### 3.2 Manuellement via OCI CLI

```bash
# Exemple: Cloudflare API Token
echo -n "votre-token" | base64 | oci vault secret update-base64 \
  --secret-id "ocid1.vaultsecret..." \
  --secret-content-content "$(cat)" \
  --force

# Exemple: Clé SSH privée
oci vault secret update-base64 \
  --secret-id "ocid1.vaultsecret..." \
  --secret-content-content "$(base64 < ~/.ssh/oci_mgmt_key)" \
  --force
```

### 3.3 Via OCI Console

1. Aller sur: https://cloud.oracle.com/vault/secrets
2. Sélectionner le secret
3. Cliquer "Create secret version"
4. Coller le contenu (base64 pour les binaires)

---

## ✅ Validation

### Vérifier les Secrets GitHub

```bash
gh secret list --repo $(gh repo view --json nameWithOwner -q .nameWithOwner)
```

### Valider le Format SSH_PUBLIC_KEY

```bash
# Doit afficher une ligne commençant par "ssh-ed25519" ou "ssh-rsa"
# Ne doit PAS contenir "-----BEGIN"
gh api repos/OWNER/REPO/actions/secrets/SSH_PUBLIC_KEY 2>/dev/null || \
  echo "Secret non accessible via API (normal, utilise gh secret list)"
```

### Tester le Workflow de Validation

```bash
# Via GitHub Actions UI:
# Actions → "Validate Secrets" → Run workflow
```

---

## 🚨 Dépannage

### Erreur: "SSH_PUBLIC_KEY must be the PUBLIC key"

**Cause**: Le secret contient une clé privée au lieu d'une clé publique.

**Solution**:
```bash
./scripts/fix-ssh-secret.sh --generate-new
```

### Erreur: "Secret not found in OCI Vault"

**Cause**: Le vault ou le secret n'existe pas encore.

**Solution**:
1. Créer les ressources via `terraform apply`
2. Ou créer le secret manuellement via OCI Console

### Erreur: "Permission denied (publickey)" sur les VMs

**Cause**: La clé privée dans OCI Vault ne correspond pas à la clé publique dans Terraform.

**Solution**:
1. Vérifier que `SSH_PUBLIC_KEY` (GitHub) = clé publique de la paire
2. Vérifier que `homelab-oci-mgmt-ssh-private-key` (OCI Vault) = clé privée de la même paire
3. Utiliser le workflow "Rotate OCI SSH key" pour synchroniser automatiquement

### Erreur: "OCI authentication failed"

**Cause**: Les secrets OCI ne sont pas correctement configurés.

**Solution**:
1. Réexécuter `./scripts/oci-session-auth-to-gh.sh`
2. Vérifier que tous les secrets OCI sont présents: `gh secret list`

---

## 📚 Références

- [Plan de stabilisation](../../.github/STABILIZATION-PLAN.md)
- [Runbook rotation secrets](../runbooks/rotate-secrets.md)
- [Guide gestion secrets](../guides/secrets-management.md)
- [Workflow de validation](../../.github/workflows/validate-secrets.yml)

---

## 🔄 Rotation des Secrets

Voir [Runbook rotation secrets](../runbooks/rotate-secrets.md) pour les procédures de rotation régulière.
