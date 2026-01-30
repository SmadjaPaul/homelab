---
sidebar_position: 3
---

# High CPU

## Symptômes

- Alerte `HighCpuUsage`
- Services lents
- Timeouts fréquents

## Impact

- Performance dégradée
- Latence utilisateur
- Possibles OOMKills si combined avec memory

## Diagnostic

### 1. Identifier la source

```bash
# Top pods par CPU
kubectl top pods -A --sort-by=cpu

# Top nodes
kubectl top nodes

# Détail d'un pod
kubectl describe pod <pod-name> -n <namespace>
```

### 2. Analyser le pod

```bash
# Logs
kubectl logs -f <pod-name> -n <namespace>

# Processes dans le container
kubectl exec -it <pod-name> -n <namespace> -- top
# ou
kubectl exec -it <pod-name> -n <namespace> -- ps aux
```

### 3. Métriques Prometheus

```promql
# CPU par pod
sum(rate(container_cpu_usage_seconds_total{namespace="<ns>"}[5m])) by (pod)

# CPU par container
rate(container_cpu_usage_seconds_total{pod="<pod>"}[5m])
```

## Résolution

### Cas 1: Application en boucle

```bash
# Identifier le process
kubectl exec -it <pod-name> -n <namespace> -- top

# Restart le pod
kubectl delete pod <pod-name> -n <namespace>
```

### Cas 2: Scaling nécessaire

```bash
# Scale up
kubectl scale deploy/<name> -n <namespace> --replicas=3

# Ou HPA
kubectl autoscale deploy/<name> --min=2 --max=5 --cpu-percent=70
```

### Cas 3: Requêtes abusives

```bash
# Vérifier les logs d'accès
kubectl logs -f <pod-name> -n <namespace> | grep -E "GET|POST"

# Si DDoS, vérifier Cloudflare
# Activer le mode Under Attack si nécessaire
```

### Cas 4: Limits trop bas

```yaml
# Augmenter les limits
resources:
  requests:
    cpu: 200m
  limits:
    cpu: 1000m  # Augmenté
```

## Optimisation

### Pour Prometheus

```bash
# Vérifier les scrape configs
kubectl get prometheusrules -A

# Réduire la fréquence de scrape si nécessaire
# scrape_interval: 30s -> 60s
```

### Pour Grafana

```bash
# Limiter les dashboards auto-refresh
# Optimiser les queries
```

## Prévention

1. Définir des resource requests/limits appropriés
2. Utiliser HPA pour auto-scaling
3. Profiler les applications régulièrement
4. Monitorer les tendances CPU
