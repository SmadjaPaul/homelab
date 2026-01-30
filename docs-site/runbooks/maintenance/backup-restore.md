---
sidebar_position: 1
---

# Backup & Restore

## Backup Velero

### Créer un backup manuel

```bash
# Backup complet
velero backup create manual-backup-$(date +%Y%m%d) \
  --include-namespaces '*' \
  --snapshot-volumes

# Backup d'un namespace
velero backup create monitoring-backup \
  --include-namespaces monitoring

# Vérifier le status
velero backup describe manual-backup-20260129
```

### Lister les backups

```bash
velero backup get

# Détails
velero backup describe <backup-name>
velero backup logs <backup-name>
```

### Restaurer

```bash
# Restore complet
velero restore create --from-backup <backup-name>

# Restore un namespace
velero restore create --from-backup <backup-name> \
  --include-namespaces <namespace>

# Restore vers un autre namespace
velero restore create --from-backup <backup-name> \
  --include-namespaces old-ns \
  --namespace-mappings old-ns:new-ns
```

### Vérifier la restauration

```bash
velero restore describe <restore-name>
velero restore logs <restore-name>

kubectl get all -n <namespace>
```

## ZFS Snapshots

### Créer un snapshot

```bash
# SSH sur Proxmox
ssh root@192.168.68.51

# Snapshot
zfs snapshot tank/vm-disks@manual-$(date +%Y%m%d-%H%M)

# Avec description
zfs snapshot -o snapdev=visible tank/vm-disks@pre-upgrade
```

### Lister les snapshots

```bash
zfs list -t snapshot -o name,creation,used,referenced
```

### Restaurer

```bash
# Rollback complet (destructif!)
zfs rollback tank/vm-disks@<snapshot>

# Ou cloner pour comparer
zfs clone tank/vm-disks@<snapshot> tank/vm-disks-clone
```

### Supprimer

```bash
# Un snapshot
zfs destroy tank/vm-disks@<snapshot>

# Tous les snapshots d'un type
zfs list -t snapshot -o name | grep "auto-" | xargs -n1 zfs destroy
```

## Backup manuel des configs

### Exporter les secrets

```bash
# Exporter (chiffré)
kubectl get secret -n <namespace> -o yaml > secrets-backup.yaml

# Chiffrer avec SOPS
sops -e secrets-backup.yaml > secrets-backup.enc.yaml
rm secrets-backup.yaml
```

### Exporter les PVCs

```bash
# Via Velero (recommandé)
velero backup create pvc-backup --include-resources persistentvolumeclaims
```

## Schedule de backup

| Type | Fréquence | Retention |
|------|-----------|-----------|
| Velero daily | 3h | 14 jours |
| Velero weekly | Dimanche 4h | 30 jours |
| ZFS hourly | Chaque heure | 24h |
| ZFS daily | Minuit | 7 jours |

## Vérification

```bash
# Dernier backup réussi
velero backup get --output=json | jq '.items | sort_by(.status.completionTimestamp) | last'

# Espace utilisé
oci os object list --bucket-name homelab-velero-backups --query "sum(data[*].size)"
```
