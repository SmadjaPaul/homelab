# Archive long terme — Données utilisateur sur OVH

Ce document décrit comment utiliser le bucket OVH **archive long terme** pour une copie hors-site des données utilisateur marquées « à ne pas perdre » (ZFS, Nextcloud). La configuration exacte (tagging, chemins, fréquence) reste à finaliser.

## Objectif

- **Velero** : backups K8s à court terme (30j), bucket dédié.
- **Archive long terme** : copie des données utilisateur critiques (ZFS, Nextcloud) sur OVH Object Storage, sans expiration par défaut, pour les données qu’on ne veut pas perdre.

Les deux buckets partagent les **3 Tio/mois** offerts (promo 3-AZ). Même utilisateur S3 et mêmes credentials pour Velero et pour l’archive.

## Bucket et credentials

- **Bucket** : `long_term_bucket_name` (défaut `homelab-user-data-archive`).
- **Credentials** : identiques à Velero (`terraform output -json velero_s3_credentials`).
- **Endpoint** : `https://s3.<region>.io.cloud.ovh.net` (ex. `gra`).

Préfixes recommandés dans le bucket :

| Préfixe     | Contenu (à finaliser)                          |
|------------|--------------------------------------------------|
| `zfs/`     | Datasets ou snapshots ZFS marqués « do not lose » |
| `nextcloud/` | Dossiers ou fichiers Nextcloud à conserver long terme |

## Marquer les données « à ne pas perdre »

### ZFS

- **Option A** : propriété custom sur un dataset, ex. `zfs set homelab:backup=longterm tank/data/users`.
- **Option B** : convention de chemin, ex. tout ce qui est sous `tank/data/archive` ou `tank/nextcloud/important`.
- Un script/cron peut lister les datasets (ou chemins) concernés et les envoyer vers OVH (snapshots + send ou rclone/restic).

### Nextcloud

- **Option A** : tag ou label sur les fichiers/dossiers (API ou interface) ; un job liste les éléments tagués et les sync vers OVH.
- **Option B** : dossier dédié « Archive long terme » ou « Do not lose » ; sync de ce dossier uniquement vers OVH.

La stratégie exacte (tag vs dossier, fréquence, rétention de versions) est à définir selon ton usage.

## Synchronisation vers OVH

### rclone (exemple)

1. Créer une config rclone pour OVH S3 (même endpoint que Velero) :

```ini
[ovh-longterm]
type = s3
provider = Other
endpoint = https://s3.gra.io.cloud.ovh.net
acl = private
```

2. Utiliser les credentials S3 (access_key / secret_key du output Terraform).

3. Exemple de sync (à adapter selon chemins et préfixes) :

```bash
# Exemple : sync d’un dataset ZFS (monté ou snapshot) vers zfs/
rclone sync /tank/data/archive ovh-longterm:homelab-user-data-archive/zfs/archive --progress

# Exemple : sync d’un dossier Nextcloud vers nextcloud/
rclone sync /var/lib/nextcloud/data/user/files/Archive ovh-longterm:homelab-user-data-archive/nextcloud/Archive --progress
```

Fréquence : cron hebdo ou mensuel selon volume et criticité (à finaliser).

### restic

- Même bucket, préfixe dédié (ex. `restic-longterm/` ou `zfs/restic/`) pour ne pas mélanger avec Velero.
- `restic -r s3:s3.gra.io.cloud.ovh.net/homelab-user-data-archive/restic-longterm backup /tank/data/archive`
- Permet déduplication et rétention par politique (keep-last, keep-yearly, etc.) ; configuration à finaliser.

### Script / automatisation

- Script qui :
  - liste les datasets ZFS ou dossiers Nextcloud « do not lose » (selon convention choisie),
  - crée des snapshots si besoin,
  - appelle rclone ou restic vers le bucket OVH avec les préfixes `zfs/` ou `nextcloud/`.
- À intégrer en cron ou systemd timer ; fréquence et rétention à finaliser.

## Récapitulatif

| Élément        | Valeur / action |
|----------------|-----------------|
| Bucket         | `homelab-user-data-archive` (ou `long_term_bucket_name`) |
| Credentials    | `velero_s3_credentials` (Terraform output) |
| Endpoint       | `https://s3.<s3_region>.io.cloud.ovh.net` |
| Préfixes       | `zfs/`, `nextcloud/` (recommandés) |
| Expiration     | Aucune par défaut ; option `long_term_expiration_days` si besoin |
| Tagging ZFS    | Propriété ou convention de chemin (à finaliser) |
| Tagging Nextcloud | Tag ou dossier dédié (à finaliser) |
| Outil de sync  | rclone, restic ou script (à finaliser) |

Une fois la convention de tagging et les chemins validés, on pourra figer un exemple de cron + rclone/restic dans ce doc ou dans la doc site (backup-restore).
