---
sidebar_position: 2
---

# Disk Full

## Symptômes

- Alerte `DiskAlmostFull` ou `DiskFull`
- Services en erreur (write failed)
- Prometheus shows disk > 85%

## Impact

- Pods ne peuvent plus écrire
- Logs perdus
- Databases corrompues possible

## Diagnostic

### 1. Identifier le disk

```bash
# Nodes K8s
kubectl top nodes

# Détail d'un node
kubectl describe node <node> | grep -A10 "Allocated resources"

# PVCs
kubectl get pvc -A
kubectl describe pvc <pvc-name> -n <namespace>
```

### 2. Proxmox/ZFS

```bash
# SSH sur Proxmox
ssh root@192.168.68.51

# Espace ZFS
zpool list
zfs list

# Espace disk
df -h
```

## Résolution

### Cas 1: Logs trop volumineux

```bash
# Identifier les gros logs
kubectl exec -it <pod> -n <namespace> -- du -sh /var/log/*

# Tronquer si nécessaire
kubectl exec -it <pod> -n <namespace> -- truncate -s 0 /var/log/app.log
```

### Cas 2: PVC plein

```bash
# Augmenter la taille (si StorageClass le permet)
kubectl patch pvc <pvc-name> -n <namespace> -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'

# Sinon, nettoyer les données
kubectl exec -it <pod> -n <namespace> -- sh
# Supprimer les fichiers inutiles
```

### Cas 3: ZFS full

```bash
# Supprimer les vieux snapshots
zfs list -t snapshot -o name,used
zfs destroy tank/vm-disks@old-snapshot

# Vérifier les datasets
zfs list -o name,used,avail
```

### Cas 4: Loki/Prometheus retention

```bash
# Vérifier la retention
kubectl get configmap -n monitoring prometheus-config -o yaml | grep retention

# Forcer cleanup Prometheus
kubectl exec -it prometheus-0 -n monitoring -- promtool tsdb clean-tombstones /prometheus
```

## Cleanup automatique

### Velero (OCI Object Storage)

Le lifecycle policy supprime automatiquement après 14 jours.

### Loki

```yaml
# Configuration
retention_period: 168h  # 7 jours
```

### ZFS snapshots

```bash
# Voir le script de retention
cat /etc/cron.daily/zfs-cleanup
```

## Prévention

1. Configurer des alerts à 70%, 80%, 90%
2. Définir des retention policies
3. Monitorer régulièrement l'espace
4. Provisionner suffisamment de storage
