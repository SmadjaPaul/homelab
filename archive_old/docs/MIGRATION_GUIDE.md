# Migration Guide: From Monolithic to Modular Docker Architecture

## 📋 Summary of Changes

### Problems with Old Setup
1. ❌ **Chicken-and-egg problem** - Terraform needed Authentik running, but Authentik needed Terraform
2. ❌ **External PostgreSQL (Aiven)** - Complex, costly, password sync issues
3. ❌ **Monolithic structure** - All services in one compose file
4. ❌ **Many environment variables** - Complex configuration
5. ❌ **Comet through tunnel** - Poor streaming performance

### New Architecture Solutions
1. ✅ **PostgreSQL local** - Simplified, with automated backup
2. ✅ **Modular structure** - Each service in its own directory
3. ✅ **Doppler injection** - `doppler run -- docker-compose up` (no .env files)
4. ✅ **External networks** - Services communicate via shared networks
5. ✅ **Comet direct IP** - No tunnel for streaming (better performance)

---

## 🚀 Step-by-Step Migration

### Phase 1: Preparation (5 minutes)

#### 1.1 Install/update Doppler CLI
```bash
# macOS
brew install doppler

# Linux
curl -Ls https://cli.doppler.com/install.sh | sh

# Login
doppler login
```

#### 1.2 Create Doppler Project
```bash
# Create infrastructure project
doppler projects create infrastructure

# Create production config
doppler configs create prd -p infrastructure
```

#### 1.3 Add Secrets to Doppler
```bash
# Required secrets
doppler secrets set DOMAIN="smadja.dev" -p infrastructure
doppler secrets set ACME_EMAIL="admin@smadja.dev" -p infrastructure

# Cloudflare
doppler secrets set CLOUDFLARE_API_TOKEN="xxx" -p infrastructure
doppler secrets set TUNNEL_TOKEN="xxx" -p infrastructure

# Authentik (generate new ones)
doppler secrets set AUTHENTIK_SECRET_KEY="$(openssl rand -base64 60 | tr -d '\n')" -p infrastructure
doppler secrets set AUTHENTIK_BOOTSTRAP_PASSWORD="YourSecurePassword123!" -p infrastructure
doppler secrets set AUTHENTIK_BOOTSTRAP_TOKEN="$(openssl rand -hex 32)" -p infrastructure
doppler secrets set AUTHENTIK_POSTGRES_PASSWORD="$(openssl rand -hex 16)" -p infrastructure

# SMTP (optional)
doppler secrets set SMTP_HOST="smtp.gmail.com" -p infrastructure
doppler secrets set SMTP_PORT="587" -p infrastructure
doppler secrets set SMTP_USERNAME="xxx" -p infrastructure
doppler secrets set SMTP_PASSWORD="xxx" -p infrastructure

# Grafana Cloud
doppler secrets set GCLOUD_RW_API_KEY="xxx" -p infrastructure
doppler secrets set GCLOUD_HOSTED_METRICS_URL="xxx" -p infrastructure
doppler secrets set GCLOUD_HOSTED_LOGS_URL="xxx" -p infrastructure

# Comet (if using streaming)
doppler secrets set RD_API_KEY="xxx" -p infrastructure
doppler secrets set COMET_POSTGRES_PASSWORD="$(openssl rand -hex 16)" -p infrastructure
```

---

### Phase 2: Setup Networks (1 minute)

```bash
cd docker

# Create shared Docker networks
docker network create traefik-public
docker network create authentik-private
docker network create monitoring
docker network create streaming
```

---

### Phase 3: Deploy Core Services (5 minutes)

#### 3.1 Deploy Traefik + Cloudflared
```bash
cd docker/core

# Deploy with Doppler
doppler run -p infrastructure -c prd -- docker-compose up -d

# Check status
docker ps
```

#### 3.2 Verify Cloudflare Tunnel
- Check Cloudflare Zero Trust dashboard
- Tunnel should show as "Healthy"

---

### Phase 4: Deploy Authentik (10 minutes)

#### 4.1 Deploy PostgreSQL + Authentik
```bash
cd docker/authentik

# Deploy
doppler run -p infrastructure -c prd -- docker-compose up -d

# Wait for PostgreSQL to be healthy
docker ps

# Check logs if needed
docker logs -f authentik-postgresql
docker logs -f authentik-server
```

#### 4.2 Initial Setup
1. Access https://auth.yourdomain.com/if/flow/initial-setup/
2. Login with `akadmin` / `AUTHENTIK_BOOTSTRAP_PASSWORD`
3. Complete setup wizard
4. **Important**: Create a non-admin user for yourself

#### 4.3 (Optional) Configure OAuth Providers
- Google OAuth2
- GitHub OAuth
- etc.

---

### Phase 5: Deploy Monitoring (2 minutes)

```bash
cd docker/monitoring
doppler run -p infrastructure -c prd -- docker-compose up -d
```

Verify in Grafana Cloud dashboard.

---

### Phase 6: Deploy Comet (Streaming) (5 minutes)

**Important**: Comet uses direct IP, NOT Cloudflare Tunnel!

#### 6.1 Configure DNS
In Cloudflare DNS:
- Create A record: `comet.yourdomain.com` → Your server IP
- **Disable proxy** (DNS only)

#### 6.2 Deploy
```bash
cd docker/services/comet
doppler run -p infrastructure -c prd -- docker-compose up -d
```

#### 6.3 Test
- Access https://comet.yourdomain.com
- Should work without authentication

---

### Phase 7: Migrate Legacy Services (Optional)

If you have data to migrate from old setup:

#### 7.1 Backup old PostgreSQL (if applicable)
```bash
# From old setup
cd docker/oci-core
docker exec oci-core-authentik-server-1 pg_dump -U postgres authentik > /tmp/authentik_backup.sql
```

#### 7.2 Restore to new PostgreSQL
```bash
# New modular setup
cat /tmp/authentik_backup.sql | docker exec -i authentik-postgresql psql -U authentik -d authentik
```

#### 7.3 Or start fresh
If no critical data, just recreate users/applications in new Authentik.

---

## 🔧 Post-Migration Configuration

### Cloudflare Access (Optional)

If you want Cloudflare Access before Authentik:

1. In Cloudflare Zero Trust → Access → Applications
2. Add self-hosted application
3. Set authentication to Authentik OIDC
4. No more chicken-and-egg! Authentik is already running.

### Backup Automation

Add to crontab:
```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /opt/docker/scripts/backup.sh all >> /var/log/docker-backup.log 2>&1
```

---

## 🧹 Cleanup Old Setup (After verification)

Once new setup is verified working:

```bash
# Stop old services
cd docker/oci-core
docker-compose down

# Remove old volumes (WARNING: Data loss if not backed up!)
docker-compose down -v

# Archive old directory
mv docker/oci-core docker/oci-core.legacy
```

---

## ✅ Verification Checklist

- [ ] Core services running (Traefik, Cloudflared)
- [ ] Authentik accessible at https://auth.yourdomain.com
- [ ] Can login to Authentik
- [ ] Prometheus accessible
- [ ] Comet accessible (if deployed)
- [ ] Backup script works
- [ ] Logs viewable

---

## 🆘 Troubleshooting

### PostgreSQL fails to start
```bash
docker logs authentik-postgresql
# Check if password is correct in Doppler
doppler secrets get AUTHENTIK_POSTGRES_PASSWORD -p infrastructure
```

### Authentik can't connect to PostgreSQL
```bash
# Check network
docker network inspect authentik-private

# Verify containers are on same network
docker ps --filter network=authentik-private
```

### Traefik not routing
```bash
# Check Traefik logs
docker logs traefik

# Verify labels on Authentik
docker inspect authentik-server --format='{{.Config.Labels}}'
```

### Doppler injection not working
```bash
# Test
doppler run -p infrastructure -c prd -- printenv | grep AUTHENTIK

# Check Doppler token
doppler configs tokens list -p infrastructure
```

---

## 📚 References

- [Doppler Docker Integration](https://docs.doppler.com/docs/docker-compose)
- [Authentik Documentation](https://docs.goauthentik.io/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Comet GitHub](https://github.com/g0ldyy/comet)

---

*Migration completed? Delete this file or archive it in docs/ folder.*
