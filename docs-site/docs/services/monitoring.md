---
sidebar_position: 2
---

# Monitoring

## Stack

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Prometheus │────▶│   Grafana   │────▶│  Dashboard  │
│  (metrics)  │     │             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
       │
       ▼
┌─────────────┐     ┌─────────────┐
│ Alertmanager│────▶│   Discord   │
│  (alerts)   │     │             │
└─────────────┘     └─────────────┘

┌─────────────┐     ┌─────────────┐
│    Loki     │◀────│  Promtail   │
│   (logs)    │     │ (collector) │
└─────────────┘     └─────────────┘
```

## Prometheus

### Configuration

Déployé via kube-prometheus-stack Helm chart.

```yaml
# kubernetes/monitoring/prometheus/application.yaml
helm:
  values: |
    prometheus:
      retention: 15d
      resources:
        requests:
          cpu: 100m
          memory: 512Mi
```

### Métriques collectées

- Node metrics (CPU, RAM, disk)
- Kubernetes metrics (pods, deployments)
- Application metrics (custom)

## Grafana

### Accès

- URL: https://grafana.smadja.dev
- Auth: Cloudflare Access + Keycloak

### Datasources

| Datasource | Type | URL |
|------------|------|-----|
| Prometheus | prometheus | http://prometheus:9090 |
| Loki | loki | http://loki:3100 |

### Dashboards

| Dashboard | ID | Description |
|-----------|-----|-------------|
| Node Exporter | 1860 | Métriques système |
| Kubernetes | 315 | Overview K8s |
| ArgoCD | 14584 | GitOps metrics |

## Alertmanager

### Configuration

```yaml
# kubernetes/monitoring/alertmanager/config.yaml
route:
  group_by: ['alertname', 'namespace']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'default'
  routes:
    - match:
        severity: critical
      receiver: 'critical'
      repeat_interval: 1h
```

### Receivers

| Receiver | Type | Usage |
|----------|------|-------|
| default | Discord webhook | Toutes les alertes |
| critical | Discord webhook | Alertes critiques |

### Alertes configurées

| Alerte | Sévérité | Description |
|--------|----------|-------------|
| NodeDown | Critical | Node inaccessible |
| HighCpuUsage | Warning | CPU > 80% |
| HighMemoryUsage | Warning | RAM > 85% |
| DiskAlmostFull | Warning | Disk > 85% |
| PodCrashLooping | Warning | Pod restart loop |
| CertificateExpiring | Warning | Cert expire < 14j |

## Loki

### Configuration

```yaml
# kubernetes/monitoring/loki/application.yaml
helm:
  values: |
    loki:
      deploymentMode: SingleBinary
      storage:
        type: filesystem
      retention_period: 168h  # 7 days
```

### Queries LogQL

```logql
# Logs d'un namespace
{namespace="monitoring"}

# Erreurs uniquement
{namespace="argocd"} |= "error"

# Parse JSON
{app="grafana"} | json | level="error"
```

## Uptime Kuma

### Status Page

URL publique: https://status.smadja.dev

Monitors configurés :
- Homepage
- Auth (Keycloak)
- Feedback (Fider)

### Notifications

- Discord webhook pour alertes
- Email (optionnel)
