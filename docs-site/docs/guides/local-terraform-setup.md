# Configuration Terraform Locale (identique à la CI)

Ce guide explique comment configurer votre environnement local pour que les `terraform apply` fonctionnent exactement comme en CI.

## Vue d'ensemble

Pour que les apply locaux fonctionnent comme en CI, il faut :
1. Configurer l'Identity Provider OCI pour OIDC (une seule fois)
2. Synchroniser les variables d'environnement locales avec la CI
3. Utiliser les mêmes configurations que la CI

## Prérequis

- OCI CLI installé et configuré (`oci setup config`)
- Accès au compartment OCI
- Clé SSH générée (`~/.ssh/oci-homelab.pub`)

## Étape 1 : Configurer l'Identity Provider OCI

L'Identity Provider permet à GitHub Actions d'authentifier via OIDC sans clés API longues durées.

### Option A : Script automatique (recommandé)

```bash
# Depuis la racine du projet
./scripts/setup-oci-identity-provider.sh \
  --compartment-id "ocid1.compartment.oc1..xxxxx" \
  --group-name "github-actions-users" \
  --repo "SmadjaPaul/homelab"
```

Le script va :
- ✅ Créer l'Identity Provider OCI
- ✅ Créer le groupe IAM `github-actions-users`
- ✅ Créer les politiques IAM nécessaires
- ⚠️  Le mapping de groupe doit être fait manuellement dans la console OCI

### Option B : Configuration manuelle

Si le script ne fonctionne pas, suivez le guide : [OCI OIDC Setup](./oci-oidc-setup.md)

## Étape 2 : Synchroniser l'environnement local

Le script `sync-local-ci-env.sh` configure automatiquement toutes les variables nécessaires :

```bash
# Synchroniser et voir le plan
./scripts/sync-local-ci-env.sh

# Synchroniser et appliquer directement
./scripts/sync-local-ci-env.sh --apply
```

Ce script :
- ✅ Récupère la configuration OCI depuis `~/.oci/config`
- ✅ Configure les variables d'environnement Terraform (identique à la CI)
- ✅ Met à jour le backend avec le namespace Object Storage
- ✅ Initialise Terraform
- ✅ Affiche le plan (ou applique si `--apply`)

## Étape 3 : Utiliser Terraform localement

Après la synchronisation, vous pouvez utiliser Terraform normalement :

```bash
cd terraform/oracle-cloud

# Plan
terraform plan

# Apply
terraform apply

# Destroy (attention!)
terraform destroy
```

## Variables d'environnement

Les variables suivantes sont automatiquement configurées par le script :

| Variable | Source | Description |
|----------|--------|-------------|
| `TF_VAR_compartment_id` | `terraform.tfvars` ou prompt | OCID du compartment |
| `TF_VAR_region` | `~/.oci/config` | Région OCI (ex: eu-paris-1) |
| `TF_VAR_user_ocid` | `~/.oci/config` | OCID de l'utilisateur OCI |
| `TF_VAR_budget_alert_email` | Hardcodé | Email pour alertes budget |
| `TF_VAR_ssh_public_key` | `~/.ssh/oci-homelab.pub` | Clé SSH publique |
| `TF_VAR_vault_secrets_managed_in_ci` | `true` | Préserve les secrets existants |

## Gestion des secrets

Les secrets du Vault OCI sont gérés différemment en local vs CI :

- **En CI** : Les secrets sont créés/gérés via GitHub Secrets → OCI Vault
- **En local** : Les secrets existants sont préservés (`vault_secrets_managed_in_ci = true`)

Pour créer/modifier des secrets localement :

```bash
# Utiliser le script interactif
./scripts/oci-vault-secrets-setup.sh
```

## Backend Terraform

Le backend utilise OCI Object Storage (gratuit dans le Free Tier) :

- **En CI** : Le namespace est injecté depuis `OCI_OBJECT_STORAGE_NAMESPACE`
- **En local** : Le script récupère automatiquement le namespace via OCI CLI

Le namespace est automatiquement injecté dans `backend.tf` par le script.

## Dépannage

### Erreur : "Backend namespace not found"

```bash
# Récupérer le namespace manuellement
oci os ns get --query 'data' --raw-output

# Mettre à jour backend.tf
sed -i.bak "s/YOUR_TENANCY_NAMESPACE/VOTRE_NAMESPACE/g" terraform/oracle-cloud/backend.tf
```

### Erreur : "Secrets will be destroyed"

C'est normal si les variables de secrets ne sont pas définies localement. Les secrets sont préservés grâce à `vault_secrets_managed_in_ci = true`.

### Erreur : "Identity Provider not found"

L'Identity Provider doit être créé une seule fois. Utilisez le script :

```bash
./scripts/setup-oci-identity-provider.sh --compartment-id "ocid1.compartment..."
```

## Workflow recommandé

1. **Première configuration** :
   ```bash
   # 1. Configurer l'Identity Provider (une fois)
   ./scripts/setup-oci-identity-provider.sh --compartment-id "ocid1..."

   # 2. Synchroniser l'environnement
   ./scripts/sync-local-ci-env.sh
   ```

2. **Travail quotidien** :
   ```bash
   cd terraform/oracle-cloud
   terraform plan
   terraform apply
   ```

3. **Avant de pousser en CI** :
   ```bash
   # Vérifier que le plan fonctionne
   ./scripts/sync-local-ci-env.sh
   ```

## Différences avec la CI

| Aspect | Local | CI |
|--------|-------|-----|
| Authentification | API Key (`~/.oci/config`) | OIDC (via GitHub Actions) |
| Backend namespace | Auto-détecté | Injecté depuis secret |
| Secrets Vault | Préservés | Créés/gérés via GitHub Secrets |
| Variables | Script `sync-local-ci-env.sh` | GitHub Secrets |

## Références

- [OCI OIDC Setup](./oci-oidc-setup.md)
- [OCI OIDC Pricing](./oci-oidc-pricing.md)
- [Terraform OCI Backend](https://developer.hashicorp.com/terraform/language/backend/oci)
