---
sidebar_position: 4
---

# High CPU

## Symptômes

- Alerte `HighCpuUsage`
- Services lents
- Timeouts

## Impact

Performance dégradée, latence utilisateur.

## Diagnostic

```bash
# Top pods
kubectl top pods -A --sort-by=cpu

# Processes dans le container
kubectl exec -it <pod> -n <namespace> -- top
```

## Résolution

### Application en boucle

```bash
# Restart le pod
kubectl delete pod <pod-name> -n <namespace>
```

### Scaling nécessaire

```bash
# Scale up
kubectl scale deploy/<name> -n <namespace> --replicas=3

# Ou HPA
kubectl autoscale deploy/<name> --min=2 --max=5 --cpu-percent=70
```

### Limits trop bas

```yaml
resources:
  limits:
    cpu: 1000m  # Augmenter
```

## Prévention

1. Resource requests/limits appropriés
2. HPA pour auto-scaling
3. Monitoring des tendances
