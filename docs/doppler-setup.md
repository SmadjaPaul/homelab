# Doppler Multi-Project Secrets Management
# =========================================

## Overview

Following MacroPower's pattern with **Terraform-generated secrets** across **multiple Doppler projects** for granular access control.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Terraform                            │
│  Generates secrets → Writes to multiple Doppler        │
│  projects (authentik, n8n, opencloud, etc.)            │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│              Doppler Cloud                              │
│  ┌─────────────────────────────────────────────────┐   │
│  │ authentik: AUTHENTIK_SECRET_KEY, ...           │   │
│  │ n8n: N8N_ENCRYPTION_KEY, ...                   │   │
│  │ opencloud: OPENCLOUD_ADMIN_PASSWORD, ...       │   │
│  │ cloudflare: TUNNEL_TOKEN                       │   │
│  │ robusta: account_id, signing_key               │   │
│  │ ... (10 projects total)                        │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                            │
                            │ Service tokens (10)
                            ▼
┌─────────────────────────────────────────────────────────┐
│                  Kubernetes                             │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 10 ClusterSecretStores (doppler-authentik, ...) │   │
│  │ ExternalSecrets → Sync secrets per project     │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Project Structure

| Project | Purpose | Secrets |
|---------|---------|---------|
| **authentik** | Identity Provider | AUTHENTIK_SECRET_KEY, AUTHENTIK_BOOTSTRAP_TOKEN, AUTHENTIK_POSTGRES_PASSWORD |
| **n8n** | Workflow automation | N8N_ENCRYPTION_KEY, N8N_POSTGRES_PASSWORD |
| **opencloud** | File storage | OPENCLOUD_ADMIN_PASSWORD, OPENCLOUD_POSTGRES_PASSWORD |
| **cloudflare** | Cloudflare services | TUNNEL_TOKEN |
| **robusta** | Monitoring & alerting | account_id, signing_key |
| **grafana** | Observability | GRAFANA_ADMIN_PASSWORD |
| **omni** | Talos management | API keys |
| **homepage** | Dashboard | Widget API keys (optional) |
| **adguard** | DNS filtering | Web password (optional) |
| **infra-core** | Core infrastructure | Additional secrets |

## Setup Instructions

### Step 1: Create Doppler Projects

```bash
# Run setup script
./scripts/setup-doppler.sh

# Or manually create each project:
doppler projects create authentik --description "Identity Provider"
doppler configs create prod -p authentik

doppler projects create n8n --description "Workflow automation"
doppler configs create prod -p n8n

# ... repeat for all 10 projects
```

### Step 2: Generate Secrets with Terraform

```bash
cd terraform/secrets

# Set your Doppler personal/CI token
export DOPPLER_TOKEN=dp.st.xxxxx

# Initialize and apply
terraform init
terraform apply
```

**Auto-generated secrets per project:**
- **authentik**: AUTHENTIK_SECRET_KEY, AUTHENTIK_BOOTSTRAP_TOKEN, AUTHENTIK_POSTGRES_PASSWORD
- **n8n**: N8N_ENCRYPTION_KEY, N8N_POSTGRES_PASSWORD
- **opencloud**: OPENCLOUD_ADMIN_PASSWORD, OPENCLOUD_POSTGRES_PASSWORD
- **grafana**: GRAFANA_ADMIN_PASSWORD
- **infra-core**: Additional infrastructure secrets

### Step 3: Add Manual Secrets

```bash
# Cloudflare Tunnel (from CF dashboard)
doppler secrets set TUNNEL_TOKEN="<your-token>" -p cloudflare -c prod

# Robusta credentials (from Robusta dashboard)
doppler secrets set account_id="<account-id>" -p robusta -c prod
doppler secrets set signing_key="<signing-key>" -p robusta -c prod

# Grafana Cloud (optional)
doppler secrets set GRAFANA_CLOUD_API_KEY="<api-key>" -p grafana -c prod
```

### Step 4: Generate Service Tokens

```bash
# Generate tokens for all projects
./scripts/generate-doppler-tokens.sh

# Apply to Kubernetes
bash /tmp/doppler-tokens-*/create-secrets.sh
```

This creates:
- Service tokens in each Doppler project
- Kubernetes secrets: `doppler-token-authentik`, `doppler-token-n8n`, etc.

### Step 5: Apply SecretStores

```bash
kubectl apply -f kubernetes/bootstrap/doppler/secret-stores.yaml

# Verify
kubectl get clustersecretstore
```

## Secret Naming Convention

Each project has its own secrets:

```bash
# authentik
AUTHENTIK_SECRET_KEY
AUTHENTIK_BOOTSTRAP_TOKEN
AUTHENTIK_POSTGRES_PASSWORD

# n8n
N8N_ENCRYPTION_KEY
N8N_POSTGRES_PASSWORD

# opencloud
OPENCLOUD_ADMIN_PASSWORD
OPENCLOUD_POSTGRES_PASSWORD

# grafana
GRAFANA_ADMIN_PASSWORD

# cloudflare
TUNNEL_TOKEN

# robusta
account_id
signing_key
```

## Secret Rotation

### Terraform-Managed Secrets

```bash
cd terraform/secrets

# Rotate specific secret
terraform apply -replace=random_password.authentik_secret_key

# ⚠️ This will restart affected pods!
```

### Manual Secrets

```bash
# Update in Doppler
doppler secrets set TUNNEL_TOKEN="<new-token>" -p cloudflare -c prod

# Force sync in Kubernetes
kubectl annotate externalsecret -n cloudflared cloudflared-token \
  force-sync=$(date +%s)
```

### Service Token Rotation

```bash
# Create new token for specific project
doppler configs tokens create prod k8s-new -p authentik --plain

# Update Kubernetes
kubectl create secret generic doppler-token-authentik \
  --from-literal=dopplerToken='<new-token>' \
  -n kube --dry-run=client -o yaml | kubectl apply -f -

# Revoke old token after verification
doppler configs tokens revoke <old-token-id> -p authentik
```

## Local Development

```bash
# Setup specific project
doppler setup --project authentik --config prod

# Run commands with secrets
doppler run -- bash -c 'echo $AUTHENTIK_SECRET_KEY'

# Or export all secrets from project
eval $(doppler secrets export --format env)
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Deploy

on: [push]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Doppler
        uses: dopplerhq/cli-action@v3

      - name: Generate Secrets
        env:
          DOPPLER_TOKEN: ${{ secrets.DOPPLER_TOKEN }}
        run: |
          cd terraform/secrets
          terraform apply -auto-approve
```

## Troubleshooting

### Secret not syncing

```bash
# Check ExternalSecret
kubectl get externalsecret -A
kubectl describe externalsecret -n authentik authentik-secrets

# Check ClusterSecretStore
kubectl get clustersecretstore doppler-authentik
kubectl describe clustersecretstore doppler-authentik

# Check ESO logs
kubectl logs -n kube deployment/external-secrets

# Force sync
kubectl annotate externalsecret -n authentik authentik-secrets \
  force-sync=$(date +%s)
```

### Token issues

```bash
# Test token for specific project
doppler secrets -p authentik -c prod --plain

# Check Kubernetes secret
kubectl get secret doppler-token-authentik -n kube -o yaml
```

## Benefits

✅ **Granular access control**: Separate projects per service
✅ **Terraform-generated**: Strong, random secrets
✅ **Easy rotation**: Per-project token rotation
✅ **MacroPower-compatible**: Same multi-project pattern
✅ **Audit trail**: Clear separation of concerns
✅ **Team permissions**: Grant access per project

## Comparison: Single vs Multi-Project

| Aspect | Single Project | Multi-Project (This) |
|--------|---------------|---------------------|
| **Projects** | 1 | 10 |
| **Tokens K8s** | 1 | 10 |
| **SecretStores** | 1 | 10 |
| **Access control** | Coarse | Granular |
| **Rotation** | All at once | Per-project |
| **Complexity** | Simple | Moderate |
| **Audit** | Harder | Easier |

## Migration from Single Project

If you have a single project setup:

1. Run `./scripts/setup-doppler.sh` to create projects
2. Migrate secrets to appropriate projects:
   ```bash
   # Get old secret
   old_value=$(doppler secrets get AUTHENTIK_SECRET_KEY --plain -p old-project -c prod)

   # Set in new project
   doppler secrets set AUTHENTIK_SECRET_KEY="$old_value" -p authentik -c prod
   ```
3. Generate new service tokens: `./scripts/generate-doppler-tokens.sh`
4. Apply to Kubernetes
5. Update applications to use new SecretStores
6. Delete old single-project setup after verification
