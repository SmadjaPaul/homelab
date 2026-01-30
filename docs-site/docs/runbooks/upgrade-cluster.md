---
sidebar_position: 6
---

# Upgrade Cluster

## Pré-requis

1. ✅ Backup récent via Velero
2. ✅ Snapshot ZFS des VMs
3. ✅ Tester en DEV d'abord

## Upgrade Talos

### 1. Version actuelle

```bash
talosctl version -n <node-ip>
```

### 2. Control planes (un à la fois)

```bash
talosctl upgrade -n <cp-node> --image ghcr.io/siderolabs/installer:v1.x.x

# Attendre Ready
kubectl get nodes -w
```

### 3. Workers

```bash
# Drain
kubectl drain <node> --ignore-daemonsets

# Upgrade
talosctl upgrade -n <worker> --image ghcr.io/siderolabs/installer:v1.x.x

# Uncordon
kubectl uncordon <node>
```

## Rollback

```bash
# Talos
talosctl rollback -n <node-ip>

# ArgoCD app
argocd app rollback <app-name> <revision>

# Velero
velero restore create --from-backup pre-upgrade
```

## Checklist post-upgrade

- [ ] Nodes Ready
- [ ] Pods Running
- [ ] ArgoCD synced
- [ ] Alertes OK
