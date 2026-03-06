# Deployment Guide

This guide details how to initialize and maintain the Homelab V1.0 infrastructure.

## 🚀 Architecture Context

The infrastructure is fully managed by **Pulumi** using Python. It provisions resources in Oracle Cloud Infrastructure (OCI) and locally via Proxmox/Talos.

```
apps.yaml (Source of Truth) → Pulumi (Python) → OKE Cluster / Cloudflare / Hetzner / Authentik
       ↑
    Doppler (Secrets)
```

## 🔄 Deployment Workflow

### 1. Update the Configuration

Most application updates are done declaratively in `kubernetes-pulumi/apps.yaml`.
- Need a new app? Add it to `apps.yaml`.
- Need a new S3 bucket? Add it to `buckets` in `apps.yaml`.

### 2. Pulumi Up

The deployment is split into three phases (stacks) for dependency management:

```bash
# 1. Foundation: Namespaces, CRDs, essential Operators (External-Secrets, Envoy Gateway)
cd kubernetes-pulumi/k8s-core
pulumi up

# 2. Storage & Databases: S3 Buckets, Redis, CloudNativePG clusters
cd ../k8s-storage
pulumi up

# 3. Applications: Helm charts, Ingress routing, Authentik Outposts
cd ../k8s-apps
pulumi up
```

### 3. Commit to Git

Once tested and successfully deployed, commit your changes:

```bash
git add .
git commit -m "feat: deployed new service"
git push
```

---

## 🔐 Secrets Management

We use **Doppler** as the single source of truth for secrets.
At runtime, Pulumi reads secrets from Doppler to:
1. Ensure fail-fast validation (`pulumi preview` will fail if a secret is missing).
2. Create `ExternalSecret` CRDs in the cluster to securely supply credentials to pods.

If you need a new secret for an app:
1. Add it to Doppler (Project: `homelab`, Config: `prd`).
2. Map it in `apps.yaml` under `secrets:` for the specific app.

---

## 🆘 Troubleshooting

### Pod CrashLoopBackOff
```bash
kubectl describe pod <pod-name> -n <ns>
kubectl logs <pod-name> -n <ns>
```

### Missing Secret (Fail-Fast during Pulumi)
If Pulumi fails with: `CRITICAL ERROR: Secret key 'XYZ' required by app '...' is MISSING in Doppler`
- Go to the Doppler Dashboard and add the missing key.
- Then run `pulumi up` again.

### Authentik OIDC / Proxy Issues
Check the Authentik embedded outpost logs:
```bash
kubectl logs -n security -l app.kubernetes.io/name=authentik -c outpost
```
Check Cloudflare Tunnel logs:
```bash
kubectl logs -n cloudflared -l app=cloudflared
```
