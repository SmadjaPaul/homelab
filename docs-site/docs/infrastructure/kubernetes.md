---
sidebar_position: 4
---

# Kubernetes

## Stack

| Composant | Technologie |
|-----------|-------------|
| OS | Talos Linux |
| Management | Omni (Sidero Labs) |
| CNI | Cilium |
| GitOps | ArgoCD |
| Ingress | Gateway API (Cilium) |

## Clusters

### DEV (Local)

| Node | Role | Resources |
|------|------|-----------|
| talos-dev | Control Plane + Worker | 2 vCPU, 4 GB |

### PROD (Oracle Cloud)

| Node | Role | Resources |
|------|------|-----------|
| oci-node-1 | Control Plane + Worker | 2 OCPU, 12 GB |
| oci-node-2 | Worker | 1 OCPU, 6 GB |

## ArgoCD

### App of Apps Pattern

```yaml
# kubernetes/argocd/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps
spec:
  source:
    path: kubernetes/apps
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Structure des applications

```
kubernetes/
├── argocd/           # ArgoCD lui-même
├── infrastructure/   # Infra (cert-manager, cloudflared, etc.)
├── monitoring/       # Prometheus, Grafana, Loki
└── apps/             # Applications utilisateur
```

### Sync Waves

| Wave | Applications |
|------|--------------|
| 0 | Cilium, cert-manager, ESO |
| 1 | Storage (Longhorn) |
| 2 | external-dns, databases |
| 3 | Monitoring stack |
| 4 | User applications |

## Cilium CNI

### Features activées

- ✅ kube-proxy replacement
- ✅ Hubble observability
- ✅ Network Policies
- ✅ Gateway API

### Network Policies

```yaml
# Deny all ingress by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

## Storage

### StorageClasses

| Name | Type | Usage |
|------|------|-------|
| local-path | Local | DEV, testing |
| longhorn | Distributed | PROD, replicated |
| nfs-media | NFS | Media library |

## Namespaces

| Namespace | Usage |
|-----------|-------|
| argocd | GitOps |
| monitoring | Prometheus, Grafana, Loki |
| cert-manager | Certificats |
| authentik | Identity |
| velero | Backups |
| uptime-kuma | Status page |
| fider | Feedback |

## Secrets Management

### SOPS + ksops

```yaml
# Secret template
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
stringData:
  password: ENC[AES256_GCM,...]
```

### External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cloudflare-api
spec:
  secretStoreRef:
    name: bitwarden
  target:
    name: cloudflare-credentials
  data:
    - secretKey: api-token
      remoteRef:
        key: cloudflare
        property: api_token
```

## Commandes utiles

```bash
# Contexte
kubectl config get-contexts
kubectl config use-context prod

# Pods
kubectl get pods -A
kubectl logs -f deploy/argocd-server -n argocd

# ArgoCD
argocd app list
argocd app sync apps

# Debug
kubectl describe pod <pod> -n <ns>
kubectl exec -it <pod> -n <ns> -- sh
```
