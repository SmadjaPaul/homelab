# ArgoCD Installation Guide

This guide explains how to install ArgoCD on the DEV Kubernetes cluster.

## Prerequisites

1. **Kubernetes cluster** (DEV cluster bootstrapped - Story 1.2.2 ✅)
2. **kubectl** configured and can access the cluster
3. **kustomize** (or kubectl 1.14+ with built-in kustomize support)

## Quick Installation

### Using Ansible (Recommended)

```bash
# Run the Ansible playbook
ansible-playbook ansible/playbooks/install-argocd.yml \
  -e "namespace=argocd" \
  -e "argocd_dir=kubernetes/argocd"

# Or with custom options
ansible-playbook ansible/playbooks/install-argocd.yml \
  -e "namespace=argocd" \
  -e "argocd_dir=kubernetes/argocd" \
  -e "wait_timeout=300"
```

The playbook will:
- Verify prerequisites (kubectl, kustomize)
- Create ArgoCD namespace
- Install ArgoCD via kustomize
- Wait for ArgoCD server to be ready
- Retrieve and display initial admin password
- Display instructions for accessing UI

### Manual Installation

```bash
# 1. Create namespace
kubectl apply -f kubernetes/argocd/namespace.yaml

# 2. Install ArgoCD using kustomize
kubectl apply -k kubernetes/argocd/

# 3. Wait for ArgoCD server to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd \
  --timeout=300s

# 4. Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

## Access ArgoCD UI

### Port-Forward (Initial Access)

```bash
# Port-forward ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser
open https://localhost:8080
# Accept self-signed certificate warning
```

### Login Credentials

- **Username**: `admin`
- **Password**: Get from secret (see above) or use the password shown by install script

### Change Admin Password

After first login, change the admin password:

```bash
# Using ArgoCD CLI
argocd login localhost:8080
argocd account update-password --account admin

# Or via UI: User Info → Update Password
```

## Verify Installation

```bash
# Check namespace
kubectl get namespace argocd

# Check pods
kubectl get pods -n argocd

# Check deployments
kubectl get deployments -n argocd

# Get ArgoCD version
kubectl exec -n argocd deployment/argocd-server -- argocd version
```

Expected pods:
- `argocd-server-*` (1 replica)
- `argocd-application-controller-*` (1 replica)
- `argocd-repo-server-*` (1 replica)
- `argocd-redis-*` (1 replica)
- `argocd-dex-server-*` (1 replica)
- `argocd-notifications-controller-*` (1 replica)

## Configuration

### Current Configuration

ArgoCD is installed using kustomize with the following configuration:

- **Namespace**: `argocd`
- **Installation**: Official ArgoCD manifests (via kustomization)
- **Mode**: Insecure (TLS terminated at Cloudflare Tunnel)
- **Resources**: Lightweight configuration for DEV cluster

### Future Access

ArgoCD will be accessible via Cloudflare Tunnel at `https://argocd.smadja.dev` (Story 3.4.1).

## Next Steps

After ArgoCD is installed:

1. **Story 1.4.2**: Configure repository connection
   - Add Git repository to ArgoCD
   - Configure SSH key or token for authentication

2. **Story 1.4.3**: Deploy App of Apps (already configured)
   - Root application is already defined in `kubernetes/argocd/app-of-apps.yaml`
   - Apply it: `kubectl apply -f kubernetes/argocd/app-of-apps.yaml`

3. **Story 1.4.4**: Configure sync waves
   - Applications already have wave annotations
   - Verify sync order in ArgoCD UI

## Troubleshooting

### Pods Not Starting

```bash
# Check pod logs
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n argocd deployment/argocd-application-controller

# Check pod events
kubectl describe pod -n argocd <pod-name>

# Check resource constraints
kubectl top pods -n argocd
```

### Cannot Access UI

1. Verify port-forward is running: `kubectl get pods -n argocd`
2. Check service: `kubectl get svc -n argocd argocd-server`
3. Try different port: `kubectl port-forward svc/argocd-server -n argocd 8081:443`

### Password Issues

```bash
# Regenerate initial admin password secret
kubectl delete secret argocd-initial-admin-secret -n argocd
kubectl rollout restart deployment argocd-server -n argocd
# Wait for pod to restart, then get new password
```

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Installation Guide](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
- [Story 1.4.1](../_bmad-output/implementation-artifacts/1-4-1-install-argocd-on-dev-cluster.md)
