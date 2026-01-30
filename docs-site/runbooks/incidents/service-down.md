---
sidebar_position: 1
---

# Service Down

## Symptômes

- Alerte `ServiceDown` dans Discord
- Page de status montre service rouge
- Utilisateurs signalent erreur 502/503

## Impact

- Service spécifique inaccessible
- Utilisateurs affectés selon le service

## Diagnostic

### 1. Identifier le service

```bash
# Vérifier les alertes actives
kubectl get prometheusrules -A

# Ou dans Alertmanager UI
open https://alerts.smadja.dev
```

### 2. Vérifier le pod

```bash
# Status des pods
kubectl get pods -n <namespace>

# Détails du pod
kubectl describe pod <pod-name> -n <namespace>

# Logs
kubectl logs -f <pod-name> -n <namespace>

# Logs précédent (si crash)
kubectl logs <pod-name> -n <namespace> --previous
```

### 3. Vérifier les events

```bash
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

## Résolution

### Cas 1: Pod en CrashLoopBackOff

```bash
# Voir les logs pour l'erreur
kubectl logs <pod-name> -n <namespace>

# Si config incorrecte, corriger et redéployer
# Sinon, rollback:
kubectl rollout undo deploy/<name> -n <namespace>
```

### Cas 2: Pod en Pending (resources)

```bash
# Vérifier les ressources du node
kubectl describe node <node>

# Si nécessaire, augmenter les resources ou scaler down autres pods
```

### Cas 3: Pod en ImagePullBackOff

```bash
# Vérifier l'image
kubectl describe pod <pod-name> -n <namespace> | grep -A5 "Image:"

# Si image privée, vérifier les secrets
kubectl get secret -n <namespace>
```

### Cas 4: Service OK mais inaccessible

```bash
# Vérifier le service
kubectl get svc -n <namespace>
kubectl get endpoints -n <namespace>

# Vérifier les ingress/tunnel
kubectl logs -f deploy/cloudflared -n cloudflared
```

## Rollback rapide

```bash
# Via kubectl
kubectl rollout undo deploy/<name> -n <namespace>

# Via ArgoCD
argocd app rollback <app-name>
```

## Prévention

1. Configurer des health checks appropriés
2. Définir des resource limits
3. Utiliser des PodDisruptionBudgets
4. Tester les changements en DEV d'abord
