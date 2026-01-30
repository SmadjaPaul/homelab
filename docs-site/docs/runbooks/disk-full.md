---
sidebar_position: 3
---

# Disk Full

## Symptômes

- Alerte `DiskAlmostFull` ou `DiskFull`
- Services en erreur (write failed)
- Disk > 85% dans Grafana

## Impact

- Pods ne peuvent plus écrire
- Logs perdus
- Databases corrompues possible

## Diagnostic

```bash
# PVCs
kubectl get pvc -A

# Proxmox/ZFS
ssh root@192.168.68.51
zpool list
df -h
```

## Résolution

### Logs trop volumineux

```bash
kubectl exec -it <pod> -n <namespace> -- truncate -s 0 /var/log/app.log
```

### PVC plein

```bash
# Augmenter la taille
kubectl patch pvc <pvc-name> -n <namespace> \
  -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'
```

### ZFS full

```bash
# Supprimer vieux snapshots
zfs list -t snapshot
zfs destroy tank/vm-disks@old-snapshot
```

## Prévention

1. Alertes à 70%, 80%, 90%
2. Retention policies
3. Monitoring régulier
