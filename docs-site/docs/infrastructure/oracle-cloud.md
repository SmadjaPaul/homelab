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
| oci-mgmt | 1 | 6 GB | 50 GB | Omni, Keycloak |
| oci-node-1 | 2 | 12 GB | 64 GB | K8s worker |
| oci-node-2 | 1 | 6 GB | 75 GB | K8s worker |
| **Total** | **4** | **24 GB** | **189 GB** | ✅ Dans les limites |

## Terraform

### Configuration

```hcl
# terraform/oracle-cloud/main.tf
provider "oci" {
  region           = var.region
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
}
```

### Déploiement

```bash
cd terraform/oracle-cloud

# Plan
terraform plan

# Apply
terraform apply
```

### Quota Validation

Le Terraform inclut une validation automatique des quotas :

```hcl
# terraform/oracle-cloud/quota-validation.tf
resource "null_resource" "quota_check" {
  lifecycle {
    precondition {
      condition     = local.total_ocpus <= 4
      error_message = "Dépasse le free tier ARM"
    }
  }
}
```

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

### Authentication issues

Vérifier :

1. Fingerprint correspond à la clé uploadée
2. Clé privée au bon format (PEM)
3. User OCID correct
4. Tenancy OCID correct

```bash
# Tester l'authentification
oci iam user get --user-id $USER_OCID
```
