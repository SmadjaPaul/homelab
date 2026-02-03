---
sidebar_position: 2
---

# Oracle Cloud

## Always Free Tier

Oracle Cloud offre des ressources gratuites à vie.

### Compute

| Shape | Limite gratuite |
|-------|-----------------|
| VM.Standard.A1.Flex (ARM) | 4 OCPUs, 24 GB RAM |
| VM.Standard.E2.1.Micro | 2 VMs (1/8 OCPU, 1 GB chaque) |

### Storage

| Type | Limite |
|------|--------|
| Block Volume | 200 GB |
| Object Storage | 20 GB |
| Archive Storage | Inclus dans 20 GB |

### Notre utilisation

| VM | OCPUs | RAM | Disk | Rôle |
|----|-------|-----|------|------|
| oci-mgmt | 1 | 6 GB | 50 GB | Omni, Authentik |
| oci-node-1 | 2 | 12 GB | 64 GB | K8s worker |
| oci-node-2 | 1 | 6 GB | 75 GB | K8s worker |
| **Total** | **4** | **24 GB** | **189 GB** | ✅ Dans les limites |

## Terraform

### Authentification

- **En local** : `~/.oci/config` ou variables d'environnement `OCI_CLI_*`.
- **En CI (GitHub Actions)** : **session token OCI** (court terme) au lieu d'une clé API. Les secrets sont générés par `./scripts/oci-session-auth-to-gh.sh` (navigateur OCI). Voir [Rotate secrets](../runbooks/rotate-secrets.md) et [.github/DEPLOYMENTS.md](https://github.com/SmadjaPaul/homelab/blob/main/.github/DEPLOYMENTS.md) ; détails Terraform : `terraform/oracle-cloud/README.md` à la racine du dépôt.

### Déploiement

```bash
cd terraform/oracle-cloud
terraform init -reconfigure   # Backend OCI Object Storage (state)
terraform plan
terraform apply
```

Le **state** est stocké dans OCI Object Storage (bucket `homelab-tfstate`). Le namespace tenancy est injecté en CI via le secret `OCI_OBJECT_STORAGE_NAMESPACE`.

### OCI Vault (secrets)

Un Vault OCI (KMS, free tier) et des secrets peuvent être créés via Terraform (variables `vault_secret_*`). En CI, les secrets existants ne sont pas détruits ni écrasés (`vault_secrets_managed_in_ci`). Voir `terraform/oracle-cloud/README.md` (section OCI Vault) à la racine du dépôt.

### Quota Validation

Le Terraform inclut une validation des quotas free tier (4 OCPUs, 24 GB RAM ARM). En cas de dépassement, le workflow échoue avant apply.

## Budget Alerts

Alertes configurées à 1€ :

| Seuil | Type | Action |
|-------|------|--------|
| 50% | Actual | Email |
| 80% | Actual | Email |
| 100% | Actual | Email |
| 100% | Forecast | Email |

## Object Storage (Velero)

Bucket pour les backups Kubernetes :

| Paramètre | Valeur |
|-----------|--------|
| Bucket | homelab-velero-backups |
| Quota | 10 GB |
| Lifecycle | Archive 7j, Delete 14j |

### S3 Compatibility

Oracle Object Storage est compatible S3 :

```
Endpoint: https://<namespace>.compat.objectstorage.eu-paris-1.oraclecloud.com
```

## Problèmes courants

### "Out of host capacity"

Les VMs ARM sont très demandées. Si vous voyez cette erreur :

1. Le script `scripts/oci-capacity-retry.sh` retente automatiquement
2. Essayez différents Availability Domains
3. Essayez aux heures creuses (tôt le matin)

```bash
# Lancer le script de retry
./scripts/oci-capacity-retry.sh
```

### Authentication issues (CI)

En CI, l'authentification utilise un **session token** (pas une clé API). Si le token a expiré (60 min par défaut), relancer :

```bash
./scripts/oci-session-auth-to-gh.sh
```

En local : vérifier `~/.oci/config` ou les variables `OCI_CLI_*`. Tester avec `oci iam user get --user-id $USER_OCID`.
