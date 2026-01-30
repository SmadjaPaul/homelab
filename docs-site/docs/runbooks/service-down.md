---
sidebar_position: 2
---

# Service Down

## Symptômes

- Alerte `ServiceDown` dans Discord
- Page de status rouge
- Erreur 502/503

## Impact

Service spécifique inaccessible.

## Diagnostic

```bash
# Status des pods
kubectl get pods -n <namespace>

# Détails
kubectl describe pod <pod-name> -n <namespace>

# Logs
kubectl logs -f <pod-name> -n <namespace>
```

## Résolution

### CrashLoopBackOff

```bash
# Voir l'erreur dans les logs
kubectl logs <pod-name> -n <namespace> --previous

# Rollback si besoin
kubectl rollout undo deploy/<name> -n <namespace>
```

### Pending (resources)

```bash
# Vérifier les resources du node
kubectl describe node <node>
```

### ImagePullBackOff

```bash
# Vérifier l'image
kubectl describe pod <pod-name> -n <namespace> | grep -A5 "Image:"
```

## Prévention

1. Health checks appropriés
2. Resource limits définis
3. PodDisruptionBudgets
