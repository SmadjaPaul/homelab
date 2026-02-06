---
sidebar_position: 7
---

# Rotation des secrets

## Fréquence

| Secret | Fréquence |
|--------|-----------|
| API tokens | 90 jours |
| DB passwords | 180 jours |
| SSH keys | 1 an |

## Recréer tous les secrets (GitHub + OCI Vault)

Si tu dois tout recréer (nouveau repo, perte des secrets, etc.) : suivre l'ordre ci-dessous.

### Étape 1 : Secrets GitHub (authentification OCI)

Ces secrets sont nécessaires pour accéder à OCI Vault.

| Ordre | Quoi | Comment |
|-------|------|---------|
| 1 | OCI session token | `./scripts/oci-session-auth-to-gh.sh` (navigateur) |
| 2 | `OCI_COMPARTMENT_ID`, `OCI_OBJECT_STORAGE_NAMESPACE`, `SSH_PUBLIC_KEY` | `./scripts/gh-secrets-setup.sh` |

**Vérifier** : `gh secret list --repo $(gh repo view --json nameWithOwner -q .nameWithOwner)`

### Étape 2 : Créer les ressources OCI Vault (Terraform)

Le vault et les secrets sont créés par Terraform :

```bash
cd terraform/oracle-cloud
TF_VAR_vault_secrets_managed_in_ci=true terraform apply
```

### Étape 3 : Peupler les secrets OCI Vault

```bash
# Vérifier l'état des secrets
./scripts/oci-vault-secrets-setup.sh --list

# Mettre à jour les valeurs (mode interactif)
./scripts/oci-vault-secrets-setup.sh
```

| Secret OCI Vault | Comment |
|------------------|---------|
| `homelab-cloudflare-api-token` | Cloudflare → API Tokens → Create Token |
| ~~`homelab-tfstate-dev-token`~~ | ~~DEPRECATED: Backend uses OCI Object Storage~~ |
| `homelab-omni-db-user` | Nom d'utilisateur PostgreSQL Omni |
| `homelab-omni-db-password` | Mot de passe fort pour PostgreSQL |
| `homelab-omni-db-name` | Nom de la base (ex: `omni`) |
| `homelab-oci-mgmt-ssh-private-key` | Clé privée SSH (même paire que `SSH_PUBLIC_KEY`) |

---

## Cloudflare API Token

```bash
# 1. Créer nouveau token sur cloudflare.com
# 2. Mettre à jour dans OCI Vault
./scripts/oci-vault-secrets-setup.sh
# (entrer le nouveau token pour homelab-cloudflare-api-token)

# 3. Si utilisé dans K8s, mettre à jour le secret
sops -d secrets/cloudflare.enc.yaml > secrets/cloudflare.yaml
# Éditer
sops -e secrets/cloudflare.yaml > secrets/cloudflare.enc.yaml
rm secrets/cloudflare.yaml

# 4. Appliquer
sops -d secrets/cloudflare.enc.yaml | kubectl apply -f -

# 5. Restart
kubectl rollout restart deploy/cloudflared -n cloudflared
```

## Oracle Cloud API Key

```bash
# 1. Générer nouvelle clé
openssl genrsa -out ~/.oci/oci_api_key_new.pem 2048

# 2. Uploader sur OCI Console

# 3. Mettre à jour ~/.oci/config

# 4. Mettre à jour les secrets GitHub (session token)
./scripts/oci-session-auth-to-gh.sh
```

## Database Passwords

```bash
# 1. Mettre à jour dans OCI Vault
./scripts/oci-vault-secrets-setup.sh
# (entrer le nouveau password pour homelab-omni-db-password)

# 2. Si PostgreSQL déjà déployé, changer le mot de passe
kubectl exec -it postgres-0 -n identity -- psql -U authentik
ALTER USER authentik WITH PASSWORD 'new-password';

# 3. Restart l'application
kubectl rollout restart deploy/authentik -n identity
```

## Vérification

- [ ] Secrets OCI Vault à jour (`./scripts/oci-vault-secrets-setup.sh --list`)
- [ ] Services fonctionnels
- [ ] CI/CD passe (déclencher un workflow test)
- [ ] Anciennes clés supprimées
