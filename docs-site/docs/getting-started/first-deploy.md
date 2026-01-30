---
sidebar_position: 3
---

# Premier déploiement

## Infrastructure

### 1. Cloudflare

```bash
cd terraform/cloudflare

terraform init
terraform plan
terraform apply
```

Ressources créées :
- DNS records pour *.smadja.dev
- Tunnel Cloudflare
- Règles WAF

### 2. Oracle Cloud

```bash
cd terraform/oracle-cloud

terraform init
terraform plan
terraform apply
```

Ressources créées :
- VCN et subnets
- VMs ARM (4 OCPU, 24 GB)
- Security lists
- Budget alerts

:::info Capacité ARM
Si vous voyez "Out of host capacity", le script `scripts/oci-capacity-retry.sh` retente automatiquement.
:::

## Kubernetes

### 1. Vérifier le cluster

```bash
kubectl get nodes
kubectl get pods -A
```

### 2. Installer ArgoCD

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Attendre que les pods soient ready
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### 3. Déployer le App of Apps

```bash
kubectl apply -f kubernetes/argocd/app-of-apps.yaml
```

ArgoCD va automatiquement synchroniser toutes les applications.

## Vérification

### ArgoCD UI

```bash
# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Ou via le tunnel
open https://argocd.smadja.dev
```

### Services

| Service | URL |
|---------|-----|
| Homepage | https://home.smadja.dev |
| Status | https://status.smadja.dev |
| Grafana | https://grafana.smadja.dev |
| ArgoCD | https://argocd.smadja.dev |

## Troubleshooting

### Pods en erreur

```bash
# Status
kubectl get pods -A | grep -v Running

# Logs
kubectl logs -f <pod-name> -n <namespace>

# Events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### ArgoCD sync failed

```bash
# Status des apps
argocd app list

# Détails
argocd app get <app-name>

# Force sync
argocd app sync <app-name> --force
```
