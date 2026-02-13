# OCI Core Services

Maximum uptime services running on Oracle Cloud Always Free tier ARM instance.
All ingress via Cloudflare Tunnel (zero open ports).

## Architecture

```
Internet → Cloudflare → Tunnel → Traefik → Services
                    ↓
              Authentik (SSO)
```

## Services Included

### Core Infrastructure
- **Traefik** - Reverse proxy with automatic SSL
- **Cloudflare Tunnel** - Secure ingress without opening ports
- **Blocky** - DNS server with ad-blocking

### Authentication
- **Authentik** - Authentication/SSO (PostgreSQL + Redis)

### VPN
- **Twingate** - Zero Trust VPN access

### Monitoring
- **Prometheus** - Metrics collection
- **Uptime Kuma** - Uptime monitoring
- **Gotify** - Push notifications
- **Grafana Agent** - Ships to Grafana Cloud (free tier)

### Applications
- **Homepage** - Service dashboard
- **Gitea** - Git hosting
- **Vaultwarden** - Password manager
- **File Browser** - File access

## Prerequisites

1. **Oracle Cloud Account** with Always Free tier
2. **ARM Instance**: VM.Standard.A1.Flex (4 OCPU, 24GB RAM)
3. **Doppler** configured with secrets
4. **Cloudflare** account with tunnel configured
5. **Grafana Cloud** account (free tier)

## Quick Start

### 1. Create ARM Instance in OCI

```bash
# Create VM in Oracle Cloud Console:
# - Shape: VM.Standard.A1.Flex
# - OCPUs: 4
# - Memory: 24GB
# - Boot Volume: 100GB
# - Image: Ubuntu 22.04 LTS
# - Add your SSH key
```

### 2. Install Docker

```bash
# SSH into your instance
ssh ubuntu@your-instance-ip

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo apt-get install docker-compose-plugin

# Logout and back in for group changes
echo "Logout and SSH back in: exit"
```

### 3. Clone Repository

```bash
git clone https://github.com/smadja-paul/homelab.git
cd homelab/docker/oci-core
```

### 4. Configure Doppler

```bash
# Install Doppler CLI
curl -Ls https://cli.doppler.com/install.sh | sudo sh

# Login
doppler login

# Verify project exists
doppler projects list
```

### 5. Add Required Secrets to Doppler

Add these to your **infrastructure** Doppler project:

```bash
# Required for core
doppler secrets set CLOUDFLARE_TUNNEL_TOKEN="your-token" -p infrastructure
doppler secrets set ACME_EMAIL="admin@smadja.dev" -p infrastructure

# Required for Authentik
doppler secrets set AUTHENTIK_SECRET_KEY="$(openssl rand -base64 60)" -p infrastructure
doppler secrets set AUTHENTIK_POSTGRES_PASSWORD="your-secure-password" -p infrastructure

# Required for Twingate
doppler secrets set TWINGATE_NETWORK="smadja" -p infrastructure
doppler secrets set TWINGATE_ACCESS_TOKEN="your-token" -p infrastructure
doppler secrets set TWINGATE_REFRESH_TOKEN="your-token" -p infrastructure

# Required for monitoring
doppler secrets set GRAFANA_CLOUD_URL="https://your-stack.grafana.net" -p infrastructure
doppler secrets set GRAFANA_CLOUD_USER="your-user" -p infrastructure
doppler secrets set GRAFANA_CLOUD_API_KEY="your-key" -p infrastructure

# Required for apps
doppler secrets set GOTIFY_DEFAULTUSER_PASS="your-password" -p infrastructure
doppler secrets set VAULTWARDEN_ADMIN_TOKEN="$(openssl rand -base64 48)" -p infrastructure

# Optional: SMTP for Authentik password reset
doppler secrets set SMTP_HOST="smtp.gmail.com" -p infrastructure
doppler secrets set SMTP_PORT="587" -p infrastructure
doppler secrets set SMTP_USERNAME="your-email@gmail.com" -p infrastructure
doppler secrets set SMTP_PASSWORD="your-app-password" -p infrastructure
doppler secrets set SMTP_FROM="noreply@smadja.dev" -p infrastructure
```

### 6. Deploy in Phases

#### Phase 1: Core Infrastructure Only

```bash
# Deploy Traefik, Cloudflare Tunnel, Blocky
doppler run --project infrastructure --config prd -- docker compose --profile core up -d

# Check status
docker ps
```

Verify:
- Visit `https://dns.smadja.dev` - Should see Blocky UI
- Check Cloudflare Tunnel dashboard - Should show connected

#### Phase 2: Add Monitoring

```bash
# Add Prometheus, Uptime Kuma, Gotify, Grafana Agent
doppler run --project infrastructure --config prd -- docker compose --profile monitoring up -d
```

Access:
- `https://status.smadja.dev` - Uptime Kuma
- `https://notify.smadja.dev` - Gotify
- Grafana Cloud dashboard

#### Phase 3: Add Applications

```bash
# Add Homepage, Gitea, Vaultwarden, File Browser
doppler run --project infrastructure --config prd -- docker compose --profile apps up -d
```

Access:
- `https://smadja.dev` - Homepage
- `https://git.smadja.dev` - Gitea
- `https://vault.smadja.dev` - Vaultwarden
- `https://files.smadja.dev` - File Browser

#### Phase 4: Add Authentik (Resource Heavy)

⚠️ **Warning**: Authentik needs ~2GB RAM. Make sure you have enough resources.

```bash
# Deploy Authentik
doppler run --project infrastructure --config prd -- docker compose --profile authentik up -d

# Wait 1-2 minutes for initialization
docker logs -f authentik-server
```

Access:
- `https://auth.smadja.dev` - Authentik

**First Login:**
- Default credentials are printed in logs or set via environment
- Check logs: `docker logs authentik-server | grep "Initial credentials"`

#### Phase 5: Add VPN

```bash
# Add Twingate connector
doppler run --project infrastructure --config prd -- docker compose --profile vpn up -d
```

### 7. Deploy Everything at Once

```bash
# All profiles
doppler run --project infrastructure --config prd -- docker compose --profile all up -d
```

## DNS Configuration

Add these A records in Cloudflare pointing to your tunnel:

```
smadja.dev → CNAME → your-tunnel-id.cfargotunnel.com
*.smadja.dev → CNAME → your-tunnel-id.cfargotunnel.com
```

Or use CNAME flattening with A record:
```
smadja.dev → A → your-instance-public-ip (if using ports)
```

**But since we're using Cloudflare Tunnel, just:**
1. Go to Cloudflare Zero Trust dashboard
2. Create a tunnel
3. Add public hostnames for each service
4. Point to `http://traefik:80` with headers

## Profile Reference

| Profile | Services | RAM Usage | Use Case |
|---------|----------|-----------|----------|
| `core` | Traefik, Tunnel, Blocky | ~500MB | Essential only |
| `monitoring` | Prometheus, Uptime Kuma, Gotify, Agent | ~1GB | Monitoring stack |
| `apps` | Homepage, Gitea, Vaultwarden, File Browser | ~1.5GB | Applications |
| `authentik` | Authentik + DB + Redis | ~2.5GB | Authentication |
| `vpn` | Twingate | ~200MB | VPN access |
| `all` | Everything | ~5-6GB | Full stack |

## Maintenance

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker logs -f traefik
```

### Update Services

```bash
# Pull latest images
doppler run --project infrastructure --config prd -- docker compose pull

# Recreate containers
doppler run --project infrastructure --config prd -- docker compose up -d
```

### Backup Data

```bash
# Create backup directory
mkdir -p ~/backups/oci-core

# Backup volumes
tar czf ~/backups/oci-core/backup-$(date +%Y%m%d).tar.gz ./data/

# Or use rclone to sync to cloud storage
```

### Monitor Resources

```bash
# Docker stats
docker stats

# System resources
htop

# Disk usage
df -h
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs
docker logs <container-name>

# Check for port conflicts
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443
```

### Cloudflare Tunnel Disconnected

```bash
# Restart tunnel
docker restart cloudflared

# Check logs
docker logs cloudflared
```

### Authentik Slow to Start

Authentik takes 1-2 minutes to initialize on first run. Check logs:
```bash
docker logs -f authentik-server
```

### Out of Memory

If OOM killer strikes:
```bash
# Check memory usage
free -h

# Reduce profile (don't run 'all')
docker compose --profile all down
docker compose --profile core up -d
```

## Security Notes

- ✅ **Zero open ports** - Everything via Cloudflare Tunnel
- ✅ **Authentik protection** - All services behind SSO
- ✅ **Automatic SSL** - Let's Encrypt certificates
- ✅ **Doppler secrets** - No secrets in repo
- ✅ **Ad-blocking DNS** - Blocky filters ads/malware

## Next Steps

1. ✅ Deploy OCI Core
2. Configure Authentik applications
3. Set up Twingate resources
4. Configure Grafana Cloud dashboards
5. Add more services as needed
6. When home lab is ready, add Tailscale/WireGuard for site-to-site VPN

## Support

- [Authentik Docs](https://goauthentik.io/docs/)
- [Traefik Docs](https://doc.traefik.io/traefik/)
- [Blocky Docs](https://0xerr0r.github.io/blocky/)
- [Grafana Cloud](https://grafana.com/docs/grafana-cloud/)
