# Secrets Management

This document describes the secrets management strategy for the homelab.

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│   Doppler   │────►│ External     │────►│   Kubernetes    │
│   (Source)  │     │ Secrets Op.  │     │   Secrets       │
└─────────────┘     └──────────────┘     └─────────────────┘
       │
       │
       ▼
┌─────────────┐
│   GitHub    │
│   Actions   │
│ (DOPPLER_   │
│  SERVICE_   │
│    TOKEN)   │
└─────────────┘
```

## Secrets Storage

### Doppler (Primary Source)

All application secrets are stored in Doppler projects:

| Project | Purpose | Secrets |
|---------|---------|---------|
| `homelab` | Core infrastructure | Cloudflare, OCI, Authentik, SSH, Flux |
| `authentik` | Authentik config | SMTP, OAuth providers |
| `cloudflare` | Cloudflare only | API tokens |
| `oracle-cloud` | OCI only | OCI credentials |

### GitHub Secrets (Bootstrap Only)

Only **one** secret is required in GitHub:

| Secret | Purpose |
|--------|---------|
| `DOPPLER_SERVICE_TOKEN` | Token to access Doppler API |

All other secrets are fetched from Doppler during deployment.

## Setup

### 1. Install Doppler CLI

```bash
brew install doppler
doppler login
```

### 2. Create Projects

```bash
doppler projects create homelab
doppler projects create authentik
doppler projects create cloudflare
doppler projects create oracle-cloud
```

### 3. Initialize Secrets

Run the initialization script:

```bash
./scripts/init-doppler-secrets.sh
```

This will guide you through setting up all required secrets.

### 4. Create Service Token

```bash
doppler configs tokens create prd homelab-prd-token -p homelab --plain
```

Copy the token and add it to GitHub:
- Go to: Settings → Secrets and variables → Actions
- Name: `DOPPLER_SERVICE_TOKEN`
- Value: Paste the token

## Secret Categories

### Infrastructure Secrets (homelab project)

| Secret | Description | Example |
|--------|-------------|---------|
| `DOMAIN` | Root domain | `smadja.dev` |
| `CLOUDFLARE_API_TOKEN` | CF API token | `xxx...` |
| `CLOUDFLARE_ZONE_ID` | Zone ID | `xxx...` |
| `CLOUDFLARE_ACCOUNT_ID` | Account ID | `xxx...` |
| `CLOUDFLARE_TUNNEL_ID` | Tunnel ID | `xxx...` |
| `CLOUDFLARE_TUNNEL_SECRET` | Tunnel secret | `base64...` |
| `CLOUDFLARE_TUNNEL_TOKEN` | Tunnel token | `xxx...` |

### OCI Secrets (homelab project)

| Secret | Description |
|--------|-------------|
| `OCI_CLI_USER` | User OCID |
| `OCI_CLI_FINGERPRINT` | API Key fingerprint |
| `OCI_CLI_TENANCY` | Tenancy OCID |
| `OCI_CLI_REGION` | Region (e.g., `eu-paris-1`) |
| `OCI_CLI_KEY_CONTENT` | API Private Key |
| `OCI_COMPARTMENT_ID` | Compartment OCID |

### Authentik Secrets (homelab project)

| Secret | Description |
|--------|-------------|
| `AUTHENTIK_URL` | URL (e.g., `https://auth.smadja.dev`) |
| `AUTHENTIK_SECRET_KEY` | Secret key (generate with `openssl rand -base64 60`) |
| `AUTHENTIK_BOOTSTRAP_PASSWORD` | Initial admin password |
| `AUTHENTIK_POSTGRES_PASSWORD` | PostgreSQL password |

### Flux GitOps Secrets (homelab project)

| Secret | Description |
|--------|-------------|
| `FLUX_GIT_SSH_KEY` | SSH private key for Flux to access Git repo |

Generate with:
```bash
ssh-keygen -t ed25519 -f /tmp/flux-ssh -N "" -C "flux@homelab"
# Add the public key as a Deploy Key in your GitHub repo
# Add the private key to Doppler
```

## External Secrets

Kubernetes secrets are synced from Doppler via External Secrets Operator:

1. **Bootstrap**: GitHub Actions creates `doppler-token` secret from `DOPPLER_SERVICE_TOKEN`
2. **External Secrets**: Syncs secrets from Doppler to Kubernetes
3. **Applications**: Read secrets from Kubernetes

### Example ExternalSecret

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secrets
  namespace: my-namespace
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: doppler
    kind: ClusterSecretStore
  target:
    name: my-app-secrets
  data:
    - secretKey: API_KEY
      remoteRef:
        key: MY_APP_API_KEY
```

## Adding New Secrets

### For Applications

1. Add secret to Doppler:
   ```bash
   doppler secrets set MY_SECRET="value" -p homelab -c prd
   ```

2. Create ExternalSecret in `kubernetes/apps/.../base/external-secret.yaml`

3. Reference in HelmRelease or Deployment

### For Terraform

Terraform uses the Doppler provider:

```hcl
data "doppler_secrets" "this" {
  project = "homelab"
  config  = "prd"
}

# Access: data.doppler_secrets.this.map.MY_SECRET
```

## Rotation

To rotate a secret:

1. Update in Doppler:
   ```bash
   doppler secrets set MY_SECRET="new-value" -p homelab -c prd
   ```

2. External Secrets will sync automatically (within `refreshInterval`)

3. Restart pods if needed:
   ```bash
   kubectl rollout restart deployment/my-app -n my-namespace
   ```

## Security Best Practices

1. **Least Privilege**: Use minimal permissions for tokens
2. **Rotation**: Rotate secrets regularly
3. **Audit**: Review Doppler audit logs
4. **No Hardcoding**: Never commit secrets to git
5. **Namespace Isolation**: Use NetworkPolicies to restrict access

## Troubleshooting

### External Secret not syncing

```bash
# Check ExternalSecret status
kubectl get externalsecret -A

# Check ClusterSecretStore
kubectl get clustersecretstore doppler -o yaml

# Check logs
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
```

### Doppler API errors

```bash
# Test token
doppler secrets download -p homelab -c prd --format json

# Verify token permissions
doppler configs tokens get prd -p homelab
```

### Flux can't access Git repo

```bash
# Check secret exists
kubectl get secret flux-system -n flux-system

# Check GitRepository status
flux get source git flux-system

# Reconcile manually
flux reconcile source git flux-system
```
