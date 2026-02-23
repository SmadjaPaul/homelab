# Bootstrap Instructions
# ======================

## Prerequisites

- kubectl configured with access to your cluster
- Doppler account
- Cloudflare account with Tunnel
- Doppler CLI installed locally (optional but recommended)
- Terraform >= 1.0

## Architecture (Multi-Project with Terraform)

Following MacroPower's pattern: Multiple Doppler projects with Terraform-generated secrets

```
Terraform generates secrets and writes to multiple Doppler projects:
- n8n: N8N_ENCRYPTION_KEY
- opencloud: OPENCLOUD_ADMIN_PASSWORD
- cloudflare: TUNNEL_TOKEN
- robusta: account_id, signing_key
- ...

Kubernetes uses service tokens per project to sync secrets via External Secrets Operator
```

## Quick Start

```bash
# 1. Setup Doppler projects
./scripts/setup-doppler.sh

# 2. Generate secrets with Terraform
cd terraform/secrets
export DOPPLER_TOKEN=dp.st.xxxxx
terraform init && terraform apply

# 3. Add manual secrets
doppler secrets set TUNNEL_TOKEN="<cf-token>" -p cloudflare -c prod
doppler secrets set account_id="<id>" -p robusta -c prod
doppler secrets set signing_key="<key>" -p robusta -c prod

# 4. Generate service tokens
./scripts/generate-doppler-tokens.sh
bash /tmp/doppler-tokens-*/create-secrets.sh

# 5. Apply SecretStores
kubectl apply -f kubernetes/bootstrap/doppler/secret-stores.yaml

# 6. Deploy
./kubernetes/bootstrap/deploy.sh oci  # or 'home'
```

## Detailed Setup

### Step 1: Doppler Setup

```bash
# Run setup script (creates 10 projects)
./scripts/setup-doppler.sh

# Or manually:
doppler projects create n8n && doppler configs create prod -p n8n
doppler projects create opencloud && doppler configs create prod -p opencloud
doppler projects create cloudflare && doppler configs create prod -p cloudflare
doppler projects create robusta && doppler configs create prod -p robusta
# ... etc for all projects
```

### Step 2: Generate Secrets with Terraform

Terraform automatically generates and writes secrets to Doppler:

```bash
cd terraform/secrets
export DOPPLER_TOKEN=dp.st.xxxxx  # Your personal/CI token
terraform init
terraform apply
```

**Auto-generated secrets:**
- `N8N_ENCRYPTION_KEY`
- `GRAFANA_ADMIN_PASSWORD`
- `POSTGRES_PASSWORD`
- And more...

### Step 3: Add External Service Secrets

```bash
# Cloudflare Tunnel (from CF dashboard)
doppler secrets set TUNNEL_TOKEN="<token>" -p cloudflare -c prod

# Robusta (from Robusta dashboard)
doppler secrets set account_id="<id>" -p robusta -c prod
doppler secrets set signing_key="<key>" -p robusta -c prod

# Grafana Cloud (optional)
doppler secrets set GRAFANA_CLOUD_API_KEY="<key>" -p grafana -c prod
```

### Step 4: Generate Service Tokens

```bash
# Generate tokens for all projects
./scripts/generate-doppler-tokens.sh

# Apply to Kubernetes
bash /tmp/doppler-tokens-*/create-secrets.sh

# Verify
kubectl get secrets -n kube | grep doppler-token
```

### Step 5: Apply SecretStores

```bash
# Apply all ClusterSecretStores
kubectl apply -f kubernetes/bootstrap/doppler/secret-stores.yaml

# Verify
kubectl get clustersecretstore
```

### Step 6: Deploy Applications

```bash
cd kubernetes

# Full deployment
./bootstrap/deploy.sh oci  # or 'home'

# Flux CD will automatically reconcile resources.
```

## Required Secrets by Project


### n8n (auto-generated)
```
N8N_ENCRYPTION_KEY
N8N_POSTGRES_PASSWORD
```

### opencloud (auto-generated)
```
OPENCLOUD_ADMIN_PASSWORD
OPENCLOUD_POSTGRES_PASSWORD
```

### grafana (auto-generated)
```
GRAFANA_ADMIN_PASSWORD
```

### cloudflare (manual)
```
TUNNEL_TOKEN
```

### robusta (manual)
```
account_id
signing_key
```

## Post-Installation


### Verify Secrets

```bash
# Check Doppler
doppler secrets -p infrastructure -c prod

# Check Kubernetes
kubectl get externalsecret -A
kubectl get secrets -A | grep -v default-token
```

## Troubleshooting

### Secrets not syncing

```bash
# Check ESO logs
kubectl logs -n kube-system deployment/external-secrets

# Check ExternalSecret
kubectl describe externalsecret -n <namespace> <name>

# Check SecretStore
kubectl describe clustersecretstore doppler

# Force sync
kubectl annotate externalsecret -n <namespace> <name> \
  force-sync=$(date +%s)
```

### Doppler token issues

```bash
# Test token for specific project
doppler secrets -p n8n -c prod --plain
```

### Terraform issues

```bash
# Re-apply secrets
cd terraform/secrets
terraform apply

terraform apply
```

## Secret Rotation

### Rotate Terraform-Managed Secrets

```bash
cd terraform/secrets
terraform apply -replace=random_password.<resource_name>
```

### Rotate Manual Secrets

```bash
# Update in specific project
doppler secrets set TUNNEL_TOKEN="<new-token>" -p cloudflare -c prod

# Kubernetes auto-syncs within 1 hour, or force:
kubectl annotate externalsecret -n cloudflared cloudflared-token \
  force-sync=$(date +%s)
```

### Rotate Service Token

```bash
# Create new token for specific project
doppler configs tokens create prod k8s-new -p n8n --plain
```

## Documentation

- [Doppler Setup Guide](../docs/doppler-setup.md) - Detailed Doppler configuration
- [Terraform Secrets](../terraform/secrets/) - Secret generation code
