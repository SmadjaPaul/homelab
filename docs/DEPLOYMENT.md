# Deployment Architecture

## 🚀 GitHub Actions Workflows

### 1. Deploy Stack (`.github/workflows/deploy-stack.yml`)

**Trigger:** Push to main OR workflow_dispatch

**Jobs:**
1. **detect-changes** - Detect which layers changed
2. **cloudflare** - Deploy Cloudflare DNS, Tunnel, Access
3. **oci** - Deploy OCI Infrastructure (VMs, Network)
4. **deploy-modular** - Deploy new modular Docker stack
5. **authentik** - Configure Authentik (legacy, optional)

**Usage:**
```bash
# Automatic on push
git push origin main

# Manual
gh workflow run deploy-stack.yml -f run_all=true
```

### 2. Manual Deploy (`.github/workflows/manual-deploy.yml`)

**Trigger:** workflow_dispatch only

**Options:**
- `all` - Run all steps
- `cloudflare` - Cloudflare only
- `oci` - OCI Infrastructure only
- `oci_mgmt` - Legacy OCI management
- `modular` - Deploy modular stack (all services)
- `core` - Traefik + Cloudflared only
- `authentik` - Authentik only
- `monitoring` - Monitoring stack only
- `comet` - Comet streaming only

**Usage:**
```bash
gh workflow run manual-deploy.yml -f step=modular
```

### 3. Deploy Modular (`.github/workflows/deploy-modular.yml`)

**Trigger:** Push to docker/** OR workflow_dispatch

**Jobs:**
- Single job that deploys services incrementally
- Uses Doppler for secrets injection

**Usage:**
```bash
gh workflow run deploy-modular.yml -f service=all
gh workflow run deploy-modular.yml -f service=comet
```

## 🏗️ Deployment Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT PIPELINE                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. CLOUDFLARE (Terraform)                                   │
│     ├── DNS Records (auth.*, stream.*, etc.)                 │
│     ├── Cloudflare Tunnel                                    │
│     ├── Access Applications                                  │
│     └── Cache Rules (Comet optimization)                     │
│                                                              │
│  2. OCI INFRASTRUCTURE (Terraform)                           │
│     ├── Management VM                                        │
│     ├── Network Security Groups                              │
│     └── Object Storage (Terraform state)                     │
│                                                              │
│  3. MODULAR DOCKER STACK                                     │
│     ├── Core: Traefik + Cloudflared                         │
│     ├── Authentik: SSO + PostgreSQL local                   │
│     ├── Monitoring: Prometheus + Grafana Alloy              │
│     └── Comet: Stremio addon (stream project)               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 🔐 Secrets Required

### GitHub Secrets

#### Infrastructure (Doppler project: `infrastructure`)
- `DOPPLER_TOKEN` - Doppler service token for infrastructure project
- `AUTHENTIK_SECRET_KEY`
- `AUTHENTIK_BOOTSTRAP_TOKEN`
- `AUTHENTIK_BOOTSTRAP_PASSWORD`
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_TUNNEL_TOKEN`
- `OCI_*` - Oracle Cloud credentials
- `SSH_PRIVATE_KEY`

#### Streaming (Doppler project: `stream`)
- `DOPPLER_TOKEN_STREAM` - Doppler service token for stream project
- `RD_API_KEY` - Real-Debrid API key
- `COMET_POSTGRES_PASSWORD`
- `RATE_LIMIT_PER_MINUTE`

## 🐳 Docker Services

### Active Services (New Architecture)

| Service | Project | Description |
|---------|---------|-------------|
| `core/` | infrastructure | Traefik + Cloudflared |
| `authentik/` | infrastructure | Authentik + PostgreSQL + Redis |
| `monitoring/` | infrastructure | Prometheus + Grafana Alloy |
| `services/comet/` | stream | Stremio addon for streaming |
| `scripts/` | - | Backup and utility scripts |

### Archived Services (Legacy)

Moved to `docker/archive/`:
- `oci-core/` - Old monolithic setup
- `arm/` - ARM-specific services
- `jellyfin/` - Media server
- `wazuh/` - SIEM
- `caddy/` - Reverse proxy (replaced by Traefik)
- `npm/` - Nginx Proxy Manager (replaced by Traefik)
- `blocky/` - DNS server
- And others...

## 📋 Deployment Checklist

Before running deployment:

- [ ] Doppler projects created (`infrastructure`, `stream`)
- [ ] All secrets configured in Doppler
- [ ] GitHub secrets added (`DOPPLER_TOKEN`, `DOPPLER_TOKEN_STREAM`)
- [ ] Cloudflare Tunnel created and token saved
- [ ] OCI VM created and accessible via SSH
- [ ] DNS records configured (optional, Terraform handles this)

## 🔄 Rollback Procedure

If deployment fails:

```bash
# 1. SSH to VM
ssh ubuntu@<VM_IP>

# 2. Check container status
cd /opt/docker
docker ps
docker-compose logs -f <service>

# 3. Rollback to previous version
docker-compose down
git checkout <previous-commit>
docker-compose up -d

# 4. Restore from backup (if needed)
./scripts/backup.sh restore <backup-file> <container>
```

## 🆘 Troubleshooting

### Container not starting
```bash
# Check logs
docker logs <container-name>

# Check Doppler injection
doppler run -p <project> -- printenv | grep <VAR>

# Verify networks
docker network ls
docker network inspect <network>
```

### DNS not resolving
```bash
# Check DNS propagation
nslookup auth.smadja.dev
nslookup stream.smadja.dev

# Check Cloudflare dashboard
# Ensure records exist and point to correct IP
```

### Doppler token issues
```bash
# Verify token has access
doppler me

# Test secrets access
doppler secrets -p infrastructure
doppler secrets -p stream
```

## 📊 Monitoring

- Grafana Dashboard: https://grafana.smadja.dev (if configured)
- Comet Dashboard: `monitoring/grafana/comet-dashboard.json`
- Logs: `docker logs -f <container>`

## 📝 Notes

- **Modular deployment** is now the preferred method
- **Legacy services** are archived in `docker/archive/`
- **Comet uses separate Doppler project** (`stream`) for isolation
- **Rate limiting** is configured at 30 req/min by default
- **Backups** run automatically after successful deployment

## 🎯 Next Steps

1. Ensure all secrets are configured
2. Run `terraform plan` to preview changes
3. Trigger `deploy-stack.yml` or `manual-deploy.yml`
4. Verify all services are healthy
5. Import Grafana dashboard for monitoring
