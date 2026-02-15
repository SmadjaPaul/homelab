# Doppler Integration Guide
# https://docs.doppler.com/docs/docker-compose

## Quick Start

### 1. Setup Doppler CLI

```bash
# macOS
brew install doppler

# Linux
curl -Ls https://cli.doppler.com/install.sh | sh

# Login
doppler login
```

### 2. Configure Projects

Create Doppler projects for your services:

```bash
# Create infrastructure project for core services
doppler projects create infrastructure

# Create project-specific configs
doppler configs create prd -p infrastructure
doppler configs create dev -p infrastructure
```

### 3. Add Secrets

Add secrets to Doppler (web UI or CLI):

```bash
# Infrastructure secrets
doppler secrets set DOMAIN="smadja.dev" -p infrastructure
doppler secrets set ACME_EMAIL="admin@smadja.dev" -p infrastructure
doppler secrets set CLOUDFLARE_API_TOKEN="xxx" -p infrastructure
doppler secrets set TUNNEL_TOKEN="xxx" -p infrastructure

# Authentik secrets
doppler secrets set AUTHENTIK_SECRET_KEY="$(openssl rand -base64 60 | tr -d '\n')" -p infrastructure
doppler secrets set AUTHENTIK_BOOTSTRAP_PASSWORD="YourSecurePassword123!" -p infrastructure
doppler secrets set AUTHENTIK_BOOTSTRAP_TOKEN="$(openssl rand -hex 32)" -p infrastructure
doppler secrets set AUTHENTIK_POSTGRES_PASSWORD="$(openssl rand -hex 16)" -p infrastructure

# SMTP (optional)
doppler secrets set SMTP_HOST="smtp.gmail.com" -p infrastructure
doppler secrets set SMTP_PORT="587" -p infrastructure
doppler secrets set SMTP_USERNAME="xxx" -p infrastructure
doppler secrets set SMTP_PASSWORD="xxx" -p infrastructure
doppler secrets set SMTP_FROM="noreply@smadja.dev" -p infrastructure

# Grafana Cloud
doppler secrets set GCLOUD_RW_API_KEY="xxx" -p infrastructure
doppler secrets set GCLOUD_HOSTED_METRICS_URL="xxx" -p infrastructure
doppler secrets set GCLOUD_HOSTED_LOGS_URL="xxx" -p infrastructure

# Comet (streaming)
doppler secrets set RD_API_KEY="xxx" -p infrastructure
doppler secrets set COMET_POSTGRES_PASSWORD="$(openssl rand -hex 16)" -p infrastructure
```

### 4. Run with Doppler

Instead of using `.env` files, inject secrets at runtime:

```bash
# Start all services
cd /opt/docker
./docker-stack.sh start all

# Or manually with Doppler
cd core
doppler run -p infrastructure -c prd -- docker-compose up -d

cd ../authentik
doppler run -p infrastructure -c prd -- docker-compose up -d
```

### 5. Generate Service Token for CI/CD

For GitHub Actions or other CI/CD:

```bash
# Create a service token
doppler configs tokens create homelab-ci-token -p infrastructure -c prd

# Set as GitHub secret
echo "DOPPLER_TOKEN=<token>" | gh secret set DOPPLER_TOKEN
```

## GitHub Actions Integration

```yaml
- name: Deploy with Doppler
  uses: dopplerhq/cli-action@v1
  env:
    DOPPLER_TOKEN: ${{ secrets.DOPPLER_TOKEN }}

- name: Start services
  run: |
    cd docker
    doppler run -p infrastructure -c prd -- ./docker-stack.sh start all
```

## Benefits

✅ **No .env files** - Secrets never touch disk
✅ **Centralized** - Update secrets in one place
✅ **Versioned** - Track secret changes
✅ **Secure** - Encrypted at rest and in transit
✅ **Access Control** - Role-based access
✅ **Audit Logs** - Track who accessed what

## Environment Variable Mapping

### Core (Traefik + Cloudflared)
- `DOMAIN` - Root domain
- `ACME_EMAIL` - Let's Encrypt email
- `CLOUDFLARE_API_TOKEN` - Cloudflare API token
- `TUNNEL_TOKEN` - Cloudflare tunnel token

### Authentik
- `AUTHENTIK_SECRET_KEY` - Authentik secret key (generate with openssl)
- `AUTHENTIK_BOOTSTRAP_PASSWORD` - Initial admin password
- `AUTHENTIK_BOOTSTRAP_TOKEN` - API token for automation
- `AUTHENTIK_POSTGRES_PASSWORD` - PostgreSQL password
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM` - Email settings

### Monitoring
- `GCLOUD_RW_API_KEY` - Grafana Cloud API key
- `GCLOUD_HOSTED_METRICS_URL` - Grafana Cloud metrics URL
- `GCLOUD_HOSTED_LOGS_URL` - Grafana Cloud logs URL

### Comet (Streaming)
- `RD_API_KEY` - Real-Debrid API key
- `COMET_POSTGRES_PASSWORD` - PostgreSQL password for Comet
- `PROXY_URL`, `PROXY_USERNAME`, `PROXY_PASSWORD` - Optional proxy for multi-IP
- `RATE_LIMIT_PER_MINUTE` - API rate limiting (default: 60)

## Troubleshooting

### Check Doppler config
```bash
doppler configs -p infrastructure
```

### Verify secrets
```bash
doppler secrets -p infrastructure
doppler secrets get AUTHENTIK_SECRET_KEY -p infrastructure
```

### Test injection
```bash
doppler run -p infrastructure -c prd -- printenv | grep AUTHENTIK
```
