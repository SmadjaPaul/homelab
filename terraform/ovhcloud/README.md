# OVHcloud Object Storage (S3 3-AZ) — Terraform

Configuration Terraform pour créer un **Object Storage S3 3-AZ** sur OVHcloud (promo 3 To/mois offerts jusqu’au 31/01/2026), avec un utilisateur dédié et **deux buckets** : **Velero** (backups K8s, rétention 30j) et **archive long terme** (données utilisateur ZFS/Nextcloud « à ne pas perdre »).

## Prérequis

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- Un projet **Public Cloud** OVH et une application API OVH

**Guide pas à pas** (création token OVH → Terraform → Velero) : [docs/setup-ovh-cloud.md](../docs/setup-ovh-cloud.md)

## Obtenir les identifiants OVH

1. **Créer une application API**
   - Aller sur [https://eu.api.ovh.com/createToken/](https://eu.api.ovh.com/createToken/)
   - Définir les droits : **GET, PUT, POST, DELETE** sur `/cloud/*` et **GET** sur `/me`
   - Valider : vous obtenez **Application Key**, **Application Secret** et **Consumer Key**

2. **Récupérer l’ID du projet Public Cloud**
   - OVH Control Panel → Public Cloud → votre projet → l’**ID du projet** (service_name, format UUID)

3. **Copier** `terraform.tfvars.example` vers `terraform.tfvars` et renseigner :
   - `ovh_application_key`, `ovh_application_secret`, `ovh_consumer_key`
   - `ovh_cloud_project_id`
   - `budget_alert_email` (email pour l’alerte à 1 €)
   - Optionnel : `s3_region` (ex. `gra` pour 3-AZ)

## Déploiement en 2 étapes

Le bucket S3 est créé via le provider AWS (endpoint OVH). Les identifiants S3 sont générés par OVH après création de l’utilisateur. Il faut donc **deux applies** :

### 1. Premier apply : utilisateur + credentials S3

Sans renseigner `ovh_s3_access_key` ni `ovh_s3_secret_key` :

```bash
cd terraform/ovhcloud
terraform init
terraform plan   # doit créer user + credential, pas de bucket
terraform apply
```

### 2. Récupérer les clés S3 et créer le bucket

```bash
# Afficher les credentials (à utiliser pour Velero et pour le 2e apply)
terraform output -json velero_s3_credentials
```

Ajouter dans `terraform.tfvars` (ou exporter en variables) :

```hcl
ovh_s3_access_key = "<access_key_id from output>"
ovh_s3_secret_key = "<secret_access_key from output>"
```

Puis :

```bash
terraform plan   # doit créer le bucket + versioning + lifecycle + blocage public
terraform apply
```

Après le second apply, les **deux buckets** sont créés (Velero + archive long terme). Les mêmes credentials servent aux deux (Velero + rclone/restic pour l’archive).

## Backend (état Terraform)

- **CI/CD** : backend HTTP TFstate.dev (voir `backend.tf`). Définir `TF_HTTP_PASSWORD` (token GitHub ou `TFSTATE_DEV_TOKEN`).
- **Local** : le fichier `backend_override.tf` force un backend local ; le supprimer pour utiliser TFstate.dev.

## Budget et quotas

- **Alerte budget** : une alerte est envoyée à `budget_alert_email` lorsque le projet Public Cloud atteint **1 €** de dépense (vérification toutes les heures). Voir `budget-alert.tf`.
- **Object Storage** : promo 3 Tio/mois offerts (3-AZ) **jusqu’au 31/01/2026**. Après cette date, la promotion s’arrête : le stockage n’est plus offert et sera facturé aux tarifs standard (les 3 To ne restent pas gratuits après expiration). Pendant la promo : partagé entre Velero et archive long terme ; au-delà de 3 Tio, facturation au Go. Velero : lifecycle 30j. Archive : pas d’expiration par défaut. Voir `quota-limits.tf` et l’output `object_storage_quota_limits`.

## Sorties utiles

| Output | Description |
|--------|-------------|
| `velero_bucket` | Bucket Velero (backups K8s, rétention 30j) |
| `long_term_bucket` | Bucket archive long terme (ZFS/Nextcloud « do not lose ») |
| `velero_s3_credentials` | Access key + secret key (Velero + archive, sensible) |
| `s3_endpoint` | URL endpoint S3 OVH (ex. `https://s3.gra.io.cloud.ovh.net`) |
| `object_storage_user_id` | ID de l’utilisateur Object Storage OVH |
| `object_storage_quota_limits` | Limites gratuites Object Storage (3 Tio/mois) |

## Archive long terme (données utilisateur)

Le bucket **archive long terme** (`long_term_bucket_name`, défaut `homelab-user-data-archive`) sert à stocker une copie des données utilisateur marquées « à ne pas perdre » (ZFS, Nextcloud). Même credentials que Velero ; préfixes recommandés : `zfs/`, `nextcloud/` (configuration à finaliser).

- **Lifecycle** : par défaut aucune expiration (`long_term_expiration_days = null`). Optionnel : définir `long_term_expiration_days` (ex. 2555 pour ~7 ans) pour une rétention limitée.
- **Sync** : rclone, restic ou script custom (voir [LONG_TERM_BACKUP.md](./LONG_TERM_BACKUP.md) pour exemples et tagging ZFS/Nextcloud).

## CI/CD (GitHub Actions)

Un workflow `terraform-ovhcloud.yml` est prévu. À configurer dans les secrets du dépôt :

- `OVH_APPLICATION_KEY`
- `OVH_APPLICATION_SECRET`
- `OVH_CONSUMER_KEY`
- `OVH_CLOUD_PROJECT_ID`
- `OVH_BUDGET_ALERT_EMAIL` (ou variable `OVH_BUDGET_ALERT_EMAIL` pour l’alerte à 1 €)
- `TFSTATE_DEV_TOKEN` (ou usage de `GITHUB_TOKEN` pour le backend)

Pour le **deuxième apply** (création du bucket), il faut soit lancer le workflow une première fois (user + credential), récupérer les credentials, les mettre en secret (ex. `OVH_S3_ACCESS_KEY`, `OVH_S3_SECRET_KEY`), puis relancer le workflow.
