# Plan de Stabilisation Prioritaire

**Date**: 2026-02-06
**Objectif**: Stabiliser rapidement le repo et corriger les problèmes bloquants

---

## 🔴 URGENT - Problèmes Bloquants

### 1. Secret SSH_PUBLIC_KEY corrompu (BLOQUANT)

**Problème**: Le secret GitHub `SSH_PUBLIC_KEY` contient une clé privée au lieu d'une clé publique.

**Solution immédiate**:
```bash
# Option 1: Utiliser le workflow de rotation (recommandé)
# Actions → "Rotate OCI SSH key" → Run workflow
# Puis: Actions → "Terraform Oracle Cloud" → action=apply, env=production

# Option 2: Corriger manuellement
# 1. Générer une nouvelle paire de clés
ssh-keygen -t ed25519 -f ~/.ssh/oci_mgmt_key -N "" -C "oci-mgmt-ci"

# 2. Mettre à jour le secret GitHub (PUBLIC KEY seulement, une ligne)
gh secret set SSH_PUBLIC_KEY --repo $(gh repo view --json nameWithOwner -q .nameWithOwner) < ~/.ssh/oci_mgmt_key.pub

# 3. Mettre à jour le secret GitHub (PRIVATE KEY)
gh secret set OCI_MGMT_SSH_PRIVATE_KEY --repo $(gh repo view --json nameWithOwner -q .nameWithOwner) < ~/.ssh/oci_mgmt_key

# 4. Mettre à jour OCI Vault (si le vault existe déjà)
# Via le workflow "Rotate OCI SSH key" ou manuellement via OCI Console
```

**Vérification**:
```bash
# Le secret doit contenir une ligne commençant par "ssh-ed25519" ou "ssh-rsa"
gh secret list --repo $(gh repo view --json nameWithOwner -q .nameWithOwner)
```

---

## 🟡 PRIORITÉ HAUTE - Nettoyage du Code Mort

### 2. Supprimer les références à TFSTATE_DEV_TOKEN (déprécié)

**Fichiers à nettoyer**:
- `scripts/gh-secrets-setup.sh` : Ligne 80 (TFSTATE_DEV_TOKEN)
- `terraform/oracle-cloud/vault-secrets.tf` : Ressource `oci_vault_secret.tfstate_dev_token` (déjà marquée DEPRECATED)
- `terraform/oracle-cloud/variables.tf` : Variable `vault_secret_tfstate_dev_token`
- `terraform/oracle-cloud/outputs.tf` : Output `tfstate_dev_token`
- `terraform/oracle-cloud/terraform.tfvars.example` : Ligne commentée
- `docs-site/docs/runbooks/rotate-secrets.md` : Référence dans le tableau
- `docs-site/docs/guides/secrets-management.md` : Référence dans le tableau
- `.github/actions/oci-vault-secrets/action.yml` : Output `tfstate_dev_token`

**Action**: Supprimer ou marquer comme obsolète avec un commentaire clair.

---

### 3. Nettoyer la documentation dupliquée

**Fichiers obsolètes**:
- ✅ `docs/` : Tous les fichiers supprimés (contenu migré vers `docs-site/`)
- ✅ `docs/README.md` : Conservé comme redirection vers `docs-site/`

---

## 🟢 PRIORITÉ MOYENNE - Améliorations

### 4. Workflow de validation des secrets

**Créer**: `.github/workflows/validate-secrets.yml`

**Fonctionnalités**:
- Valider le format de `SSH_PUBLIC_KEY` (une ligne, commence par `ssh-`)
- Vérifier la présence des secrets requis
- Valider que les secrets OCI sont accessibles (test de connexion)

**Déclenchement**: Sur PR, workflow_dispatch, et avant les workflows Terraform.

---

### 5. Guide de setup des secrets

**Créer**: `docs-site/docs/getting-started/secrets-setup.md`

**Contenu**:
- Checklist des secrets requis
- Ordre de création (dépendances)
- Scripts d'aide (`gh-secrets-setup.sh`, `oci-session-auth-to-gh.sh`)
- Procédure de récupération en cas d'erreur

---

## 📋 Checklist de Stabilisation

### Phase 1: Correction Immédiate (Aujourd'hui)
- [ ] Corriger `SSH_PUBLIC_KEY` (workflow de rotation ou manuel)
- [ ] Tester le workflow `terraform-oci.yml` (plan seulement)
- [ ] Vérifier que les secrets OCI sont accessibles

### Phase 2: Nettoyage (Cette semaine)
- [ ] Supprimer les références à `TFSTATE_DEV_TOKEN`
- [ ] Nettoyer la documentation dupliquée
- [ ] Mettre à jour les runbooks avec les nouvelles procédures

### Phase 3: Améliorations (Ce mois)
- [ ] Créer le workflow de validation des secrets
- [ ] Créer le guide de setup des secrets
- [ ] Documenter la procédure de récupération d'urgence

---

## 🔍 Secrets Requis (Référence Rapide)

### GitHub Secrets (authentification OCI)
- `OCI_CLI_TENANCY` - OCID du tenancy
- `OCI_CLI_USER` - OCID de l'utilisateur
- `OCI_CLI_FINGERPRINT` - Empreinte de la clé API
- `OCI_CLI_REGION` - Région (ex: `eu-paris-1`)
- `OCI_CLI_KEY_CONTENT` - Contenu de la clé API privée (PEM)
- `OCI_DOMAIN_URL` - URL du domaine OCI (pour OIDC)
- `OCI_OIDC_CLIENT_ID` - Client ID OIDC
- `OCI_OIDC_CLIENT_SECRET` - Client secret OIDC
- `OCI_COMPARTMENT_ID` - OCID du compartment
- `OCI_OBJECT_STORAGE_NAMESPACE` - Namespace Object Storage
- `SSH_PUBLIC_KEY` - **CLÉ PUBLIQUE** SSH (une ligne, commence par `ssh-ed25519` ou `ssh-rsa`)
- `OCI_MGMT_SSH_PRIVATE_KEY` - Clé privée SSH (PEM complet)
- `GH_TOKEN` - GitHub PAT avec `admin:repo` (pour rotation automatique des secrets)
- `CLOUDFLARE_API_TOKEN` - Token API Cloudflare

### OCI Vault Secrets (créés par Terraform)
- `homelab-cloudflare-api-token` - Token API Cloudflare
- `homelab-omni-db-user` - Utilisateur PostgreSQL Omni
- `homelab-omni-db-password` - Mot de passe PostgreSQL Omni
- `homelab-omni-db-name` - Nom de la base Omni
- `homelab-oci-mgmt-ssh-private-key` - Clé privée SSH (même paire que `SSH_PUBLIC_KEY`)

---

## 🚨 Procédure de Récupération d'Urgence

Si le repo est complètement cassé :

1. **Vérifier les secrets GitHub**:
   ```bash
   gh secret list --repo $(gh repo view --json nameWithOwner -q .nameWithOwner)
   ```

2. **Corriger SSH_PUBLIC_KEY**:
   ```bash
   # Générer nouvelle paire
   ssh-keygen -t ed25519 -f ~/.ssh/oci_mgmt_key -N "" -C "oci-mgmt-ci"

   # Mettre à jour GitHub (PUBLIC seulement)
   gh secret set SSH_PUBLIC_KEY < ~/.ssh/oci_mgmt_key.pub
   gh secret set OCI_MGMT_SSH_PRIVATE_KEY < ~/.ssh/oci_mgmt_key
   ```

3. **Tester le workflow**:
   ```bash
   # Via GitHub Actions UI: "Terraform Oracle Cloud" → action=plan, env=development
   ```

4. **Si OCI Vault existe déjà**:
   - Utiliser le workflow "Rotate OCI SSH key" pour synchroniser automatiquement

---

## 📚 Références

- [Rotate secrets runbook](docs-site/docs/runbooks/rotate-secrets.md)
- [Secrets management guide](docs-site/docs/guides/secrets-management.md)
- [OCI session auth script](../scripts/oci-session-auth-to-gh.sh)
- [GitHub secrets setup script](../scripts/gh-secrets-setup.sh)
