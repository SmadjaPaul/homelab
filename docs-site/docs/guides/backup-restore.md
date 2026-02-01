---
sidebar_position: 4
---

# Backup & Recovery

## Stratégie 3-2-1

- **3** copies des données
- **2** supports différents
- **1** copie hors-site

### Implémentation

| Copie | Localisation | Type |
|-------|--------------|------|
| 1 | Proxmox ZFS | Local |
| 2 | Oracle Object Storage (Velero) | Cloud — backups K8s, rétention 30j |
| 3 | OVH Object Storage (archive long terme) | Cloud — données utilisateur « à ne pas perdre » (ZFS, Nextcloud) |

La copie hors-site inclut **OVH Object Storage** (3 Tio offerts, promo 3-AZ) pour Velero et l’archive long terme (ZFS, Nextcloud). Pour mettre en place la connexion OVH (Terraform + Velero), voir le guide **Setup OVH Cloud** : `docs/setup-ovh-cloud.md` à la racine du repo. Détails archive long terme : [LONG_TERM_BACKUP.md](https://github.com/SmadjaPaul/homelab/blob/main/terraform/ovhcloud/LONG_TERM_BACKUP.md).

## Velero

### Configuration

```yaml
# Backups quotidiens
schedules:
  daily-backup:
    schedule: "0 3 * * *"  # 3h du matin
    template:
      ttl: "336h"  # 14 jours
      includedNamespaces:
        - "*"
      snapshotVolumes: true
```

### Commandes

```bash
# Créer un backup manuel
velero backup create full-backup --include-namespaces '*'

# Lister les backups
velero backup get

# Restaurer
velero restore create --from-backup full-backup

# Voir les logs
velero backup logs <backup-name>
```

### Storage

| Paramètre | Valeur |
|-----------|--------|
| Backend | Oracle Object Storage (S3) |
| Bucket | homelab-velero-backups |
| Quota | 10 GB |
| Retention | 14 jours (auto-delete) |

## ZFS Snapshots

### Configuration

```bash
# Snapshot automatique
cat > /etc/cron.hourly/zfs-snapshot << 'EOF'
#!/bin/bash
zfs snapshot tank/vm-disks@auto-$(date +%Y%m%d-%H%M)
EOF
```

### Commandes

```bash
# Créer un snapshot
zfs snapshot tank/vm-disks@backup-$(date +%Y%m%d)

# Lister les snapshots
zfs list -t snapshot

# Restaurer un fichier
zfs diff tank/vm-disks@backup-20260129

# Rollback complet
zfs rollback tank/vm-disks@backup-20260129
```

### Retention

| Fréquence | Retention |
|-----------|-----------|
| Hourly | 24 dernières |
| Daily | 7 derniers jours |
| Weekly | 4 dernières semaines |

### Archive long terme (OVH) — données « à ne pas perdre »

Certaines données ZFS ou Nextcloud peuvent être marquées (tag, propriété ZFS ou dossier dédié) pour signaler qu’elles ne doivent pas être perdues. Une copie est envoyée sur **OVH Object Storage** (bucket archive long terme) :

- **Préfixes** : `zfs/`, `nextcloud/` dans le bucket `homelab-user-data-archive`
- **Rétention** : pas d’expiration par défaut (configuration Terraform `long_term_expiration_days = null`)
- **Sync** : rclone, restic ou script (détails et exemples dans [LONG_TERM_BACKUP.md](https://github.com/SmadjaPaul/homelab/blob/main/terraform/ovhcloud/LONG_TERM_BACKUP.md))

La convention de tagging et la fréquence des syncs restent à finaliser.

## Disaster Recovery

### Scénario 1: Namespace supprimé

```bash
# 1. Identifier le backup
velero backup get

# 2. Restaurer le namespace
velero restore create --from-backup daily-backup \
  --include-namespaces deleted-namespace

# 3. Vérifier
kubectl get all -n deleted-namespace
```

### Scénario 2: Cluster perdu

```bash
# 1. Réinstaller le cluster
talosctl apply-config ...

# 2. Installer ArgoCD
kubectl apply -f kubernetes/argocd/

# 3. Attendre Velero sync

# 4. Restaurer depuis backup
velero restore create --from-backup weekly-full
```

### Scénario 3: Corruption VM Proxmox

```bash
# 1. Lister les snapshots ZFS
zfs list -t snapshot tank/vm-disks

# 2. Rollback
zfs rollback tank/vm-disks@backup-20260129

# 3. Démarrer la VM
qm start <vmid>
```

## Monitoring des backups

### Alertes Prometheus

| Alerte | Condition |
|--------|-----------|
| VeleroBackupFailed | Backup échoué |
| VeleroNoRecentBackup | Pas de backup en 25h |
| VeleroStorageUnavailable | S3 inaccessible |

### Vérification manuelle

```bash
# Status Velero
velero backup get

# Espace utilisé (OCI)
oci os object list \
  --bucket-name homelab-velero-backups \
  --query "sum(data[*].size)"
```

## Best Practices

1. **Tester les restaurations** régulièrement
2. **Monitorer les alertes** de backup
3. **Documenter les procédures** (ce document!)
4. **Chiffrer les backups** (Velero + encryption)
5. **Vérifier les quotas** storage
