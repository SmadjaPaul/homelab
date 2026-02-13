# OCI Core - Quick Start Guide

Deploy maximum uptime services on Oracle Cloud Always Free tier in 5 minutes.

## 🚀 Quick Deploy

```bash
# SSH into your OCI ARM instance
ssh ubuntu@your-instance-ip

# Clone repo
git clone https://github.com/smadja-paul/homelab.git
cd homelab/docker/oci-core

# Install Doppler CLI
curl -Ls https://cli.doppler.com/install.sh | sudo sh
doppler login

# Deploy!
./deploy.sh core
```

## 📋 Prerequisites Checklist

Before deploying, make sure you have:

- [ ] **OCI ARM Instance** created (4 OCPU, 24GB RAM)
- [ ] **Docker installed** on the instance
- [ ] **Doppler account** with projects created
- [ ] **Cloudflare** tunnel configured
- [ ] **Grafana Cloud** account (free tier)
- [ ] **Twingate** network configured

## 🔐 Required Doppler Secrets

Add these to your **infrastructure** project:

```bash
# Core (Required)
doppler secrets set CLOUDFLARE_TUNNEL_TOKEN="xxx" -p infrastructure
doppler secrets set ACME_EMAIL="admin@smadja.dev" -p infrastructure

# Authentik (Required for auth profile)
doppler secrets set AUTHENTIK_SECRET_KEY="$(openssl rand -base64 60)" -p infrastructure
doppler secrets set AUTHENTIK_POSTGRES_PASSWORD="secure-pass" -p infrastructure

# Twingate (Required for vpn profile)
doppler secrets set TWINGATE_ACCESS_TOKEN="xxx" -p infrastructure
doppler secrets set TWINGATE_REFRESH_TOKEN="xxx" -p infrastructure

# Grafana Cloud (Required for monitoring profile)
doppler secrets set GRAFANA_CLOUD_URL="https://xxx.grafana.net" -p infrastructure
doppler secrets set GRAFANA_CLOUD_USER="xxx" -p infrastructure
doppler secrets set GRAFANA_CLOUD_API_KEY="xxx" -p infrastructure

# Apps (Required for apps profile)
doppler secrets set GOTIFY_DEFAULTUSER_PASS="xxx" -p infrastructure
doppler secrets set VAULTWARDEN_ADMIN_TOKEN="$(openssl rand -base64 48)" -p infrastructure
```

## 🎯 Deployment Profiles

| Command | Services | RAM | Time |
|---------|----------|-----|------|
| `./deploy.sh core` | Traefik + Tunnel + Blocky | 500MB | 1 min |
| `./deploy.sh monitoring` | Prometheus + Uptime + Gotify + Agent | 1GB | 1 min |
| `./deploy.sh apps` | Homepage + Gitea + Vault + Files | 1.5GB | 1 min |
| `./deploy.sh authentik` | Auth + DB + Redis | 2.5GB | 3 min |
| `./deploy.sh vpn` | Twingate | 200MB | 30 sec |
| `./deploy.sh all` | Everything | 6GB | 5 min |

## 🌐 Access Your Services

After deployment:

- **Homepage**: https://smadja.dev
- **Auth**: https://auth.smadja.dev
- **Git**: https://git.smadja.dev
- **Vault**: https://vault.smadja.dev
- **Files**: https://files.smadja.dev
- **Status**: https://status.smadja.dev
- **DNS**: https://dns.smadja.dev
- **Notify**: https://notify.smadja.dev

## 🛠️ Common Commands

```bash
# View status
./deploy.sh status

# View logs
./deploy.sh logs
docker logs -f traefik

# Update all services
./deploy.sh update

# Stop everything
./deploy.sh down

# Restart single service
docker restart vaultwarden
```

## 🔧 Manual Docker Commands

```bash
# Deploy with Doppler
doppler run --project infrastructure --config prd -- \
    docker compose --profile core up -d

# View logs
doppler run --project infrastructure --config prd -- \
    docker compose logs -f

# Scale specific service
doppler run --project infrastructure --config prd -- \
    docker compose up -d --force-recreate vaultwarden
```

## 📊 Resource Usage

Monitor with:

```bash
# Docker stats
docker stats

# System resources
htop
free -h
df -h
```

## 🆘 Troubleshooting

**Service won't start:**
```bash
docker logs <container-name>
```

**Out of memory:**
```bash
# Check usage
free -h

# Stop heavy services
docker stop authentik-server authentik-worker
```

**Tunnel not connecting:**
```bash
docker logs cloudflared
docker restart cloudflared
```

## 📝 Next Steps

1. ✅ Deploy core infrastructure
2. ✅ Verify Cloudflare Tunnel is connected
3. ✅ Configure Authentik (create user, disable public registration)
4. ✅ Set up Twingate resources (add internal IPs)
5. ✅ Create Grafana Cloud dashboards
6. ✅ Configure Gitea (disable registration)
7. ✅ Set up Vaultwarden (create account)
8. ✅ Test file upload/download

## 🔗 Useful Links

- [Authentik Docs](https://goauthentik.io/docs/)
- [Traefik Dashboard](https://traefik.smadja.dev)
- [Grafana Cloud](https://grafana.com)
- [Cloudflare Zero Trust](https://one.dash.cloudflare.com)
- [Twingate Admin](https://smadja.twingate.com)

---

**Need help?** Check the full README.md or run: `./deploy.sh`
