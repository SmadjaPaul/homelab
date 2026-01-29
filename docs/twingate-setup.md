# Twingate Zero Trust VPN Setup

## Overview

Twingate provides zero-trust network access to your homelab without exposing ports to the internet.

**Free Tier Includes:**
- 5 users
- 1 remote network
- Unlimited connectors
- All features

## How It Works

```
Your Device → Twingate Client → Twingate Cloud → Connector (in K8s) → Internal Services
```

Benefits over traditional VPN:
- No open ports on your network
- Per-resource access control
- Works through NAT/firewalls
- Split tunneling by default

## Setup Guide

### 1. Create Twingate Account

1. Go to https://www.twingate.com
2. Sign up (free tier)
3. Choose a network name (e.g., `smadja`)

### 2. Create Remote Network

1. Admin Console → Networks → Add Remote Network
2. Name it "Homelab Kubernetes"
3. Click "Deploy Connector"

### 3. Get Connector Tokens

1. Choose "Docker" deployment
2. Copy the environment variables:
   - `TWINGATE_NETWORK`
   - `TWINGATE_ACCESS_TOKEN`
   - `TWINGATE_REFRESH_TOKEN`

### 4. Deploy to Kubernetes

```bash
# Create namespace
kubectl create namespace twingate

# Create secret with your tokens
kubectl create secret generic twingate-credentials -n twingate \
  --from-literal=network="smadja" \
  --from-literal=access-token="YOUR_ACCESS_TOKEN" \
  --from-literal=refresh-token="YOUR_REFRESH_TOKEN"

# Deploy connector (via ArgoCD or manually)
kubectl apply -f kubernetes/infrastructure/twingate/manifests/
```

### 5. Define Resources

In Twingate Admin Console → Resources:

| Resource | Address | Protocols |
|----------|---------|-----------|
| Kubernetes Services | `*.svc.cluster.local` | TCP |
| Pod Network | `10.244.0.0/16` | TCP/UDP |
| Service Network | `10.96.0.0/12` | TCP |
| Proxmox | `192.168.68.51` | TCP 8006 |
| Home Network | `192.168.68.0/24` | All |

### 6. Install Twingate Client

Download from: https://www.twingate.com/download

Available for:
- macOS
- Windows
- Linux
- iOS
- Android

### 7. Connect

1. Open Twingate client
2. Enter your network name (e.g., `smadja`)
3. Login with your account
4. Resources are now accessible!

## Usage Examples

```bash
# Access Kubernetes API
kubectl --server=https://kubernetes.default.svc:6443 get pods

# Access Grafana internally
curl http://grafana.monitoring.svc.cluster.local:3000

# SSH to Proxmox
ssh root@192.168.68.51

# Access ArgoCD
open https://argocd-server.argocd.svc.cluster.local
```

## Access Policies

Create groups in Twingate for different access levels:

| Group | Resources |
|-------|-----------|
| `admins` | All resources |
| `developers` | Kubernetes, Grafana, ArgoCD |
| `monitoring` | Grafana only |

## Troubleshooting

### Connector not connecting

```bash
# Check connector logs
kubectl logs -n twingate deploy/twingate-connector

# Verify credentials
kubectl get secret twingate-credentials -n twingate -o yaml
```

### Resources not accessible

1. Check Resource definitions in Twingate Admin
2. Verify your user has access to the Resource
3. Check connector is online in Admin Console

## Comparison with Cloudflare Tunnel

| Feature | Twingate | Cloudflare Tunnel |
|---------|----------|-------------------|
| Access type | VPN-like | Reverse proxy |
| Protocol | Any TCP/UDP | HTTP/HTTPS only |
| Use case | Internal tools, SSH | Public websites |
| Auth | Twingate account | Cloudflare Access |
| Split tunnel | Yes | N/A |

**Recommendation:** Use both!
- Twingate for internal access (SSH, kubectl, internal dashboards)
- Cloudflare Tunnel for public-facing services
