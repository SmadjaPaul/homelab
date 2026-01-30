---
sidebar_position: 2
---

# Upgrade Cluster

## Pré-requis

1. ✅ Backup récent via Velero
2. ✅ Snapshot ZFS des VMs
3. ✅ Tester en DEV d'abord
4. ✅ Période de maintenance planifiée

## Upgrade Talos

### 1. Vérifier la version actuelle

```bash
talosctl version -n <node-ip>
kubectl get nodes -o wide
```

### 2. Télécharger la nouvelle version

```bash
# Via Omni (si utilisé)
# Ou manuellement
talosctl upgrade --nodes <node-ip> --image ghcr.io/siderolabs/installer:v1.x.x
```

### 3. Upgrade les control planes

```bash
# Un node à la fois
talosctl upgrade -n <cp-node-1> --image ghcr.io/siderolabs/installer:v1.x.x

# Attendre que le node soit Ready
kubectl get nodes -w

# Puis le suivant
talosctl upgrade -n <cp-node-2> --image ghcr.io/siderolabs/installer:v1.x.x
```

### 4. Upgrade les workers

```bash
# Drain le node
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

# Upgrade
talosctl upgrade -n <worker-node> --image ghcr.io/siderolabs/installer:v1.x.x

# Uncordon
kubectl uncordon <node>
```

### 5. Vérifier

```bash
talosctl version -n <node-ip>
kubectl get nodes
kubectl get pods -A
```

## Upgrade Kubernetes

### Via Talos

```bash
# Upgrade la config Talos avec la nouvelle version K8s
talosctl upgrade-k8s -n <cp-node> --to 1.xx.x
```

### Vérifier les composants

```bash
kubectl get pods -n kube-system
kubectl version
```

## Upgrade ArgoCD

### Via Git (recommandé)

1. Mettre à jour la version dans `kubernetes/argocd/install.yaml`
2. Commit & push
3. ArgoCD se met à jour lui-même

### Vérifier

```bash
argocd version
kubectl get pods -n argocd
```

## Upgrade Helm charts

### Via Renovate (automatique)

Renovate crée des PRs pour les mises à jour de charts.

### Manuellement

```bash
# Mettre à jour la version dans application.yaml
# Exemple:
helm:
  chart: grafana
  targetRevision: 7.0.0  # Nouvelle version

# Commit & push
# ArgoCD sync
```

## Rollback

### Talos

```bash
talosctl rollback -n <node-ip>
```

### ArgoCD app

```bash
argocd app history <app-name>
argocd app rollback <app-name> <revision>
```

### Velero

```bash
velero restore create --from-backup pre-upgrade-backup
```

## Checklist post-upgrade

- [ ] Tous les nodes Ready
- [ ] Tous les pods Running
- [ ] ArgoCD synced
- [ ] Monitoring fonctionnel
- [ ] Alertes pas déclenchées
- [ ] Tests fonctionnels OK
