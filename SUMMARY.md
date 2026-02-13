# Homelab Changes Summary

## 🎯 Changes Made

### 1. Authentik with External PostgreSQL (Supabase)

**Problem**: PostgreSQL on local VM loses data when VM is recreated

**Solution**: Moved PostgreSQL to **Supabase** (free cloud tier)

**Benefits**:
- ✅ Data survives VM recreation
- ✅ Managed backups (automated by Supabase)
- ✅ SSL encryption
- ✅ IP restrictions (only OCI VM can connect)
- ✅ 500MB free tier (sufficient for Authentik)

**Files Modified**:
- `docker/oci-core/docker-compose.yml` - Removed local PostgreSQL, configured external connection
- `doppler.yaml` - Added `AUTHENTIK_POSTGRES_*` secrets
- `scripts/setup-supabase-postgres.sh` - Interactive setup script

**Setup Command**:
```bash
./scripts/setup-supabase-postgres.sh
```

### 2. Risk Analysis Document

Created comprehensive risk analysis:

**File**: `docs/RISK_ANALYSIS.md`

**Key Findings**:
- 🔴 Critical: VM recreation destroys local data
- 🔴 Critical: Single VM = single point of failure
- 🟡 Medium: Monitoring needs alerting

**Mitigation Strategies**:
1. Backup script for local data (created)
2. Multi-VM deployment (recommended)
3. Grafana Cloud alerts (in progress)

### 3. Grafana Cloud Automation

**Problem**: Manual setup of Grafana Cloud is tedious

**Solution**: Automated CLI script

**Files Created**:
- `scripts/setup-grafana-cloud.sh` - Interactive setup
- `scripts/backup-local-data.sh` - Daily backup automation

**Features**:
- Automatically detects endpoints
- Tests connection
- Configures Doppler
- Creates alloy.config
- Saves credentials securely

**Setup Command**:
```bash
./scripts/setup-grafana-cloud.sh
```

### 4. Scripts Created

| Script | Purpose | Usage |
|--------|---------|-------|
| `setup-supabase-postgres.sh` | Configure Supabase PostgreSQL | Run once |
| `setup-grafana-cloud.sh` | Setup Grafana Cloud integration | Run once |
| `backup-local-data.sh` | Backup local data to OCI | Daily cron |
| `generate-authelia-password.sh` | Generate password hash (legacy) | If using Authelia |

## 🚀 Deployment Steps

### Step 1: Setup Supabase PostgreSQL

```bash
# Run interactive setup
./scripts/setup-supabase-postgres.sh

# Follow prompts to:
# 1. Create Supabase account
# 2. Create project
# 3. Configure IP restrictions
# 4. Get connection string
# 5. Test connection
# 6. Add to Doppler
```

### Step 2: Setup Grafana Cloud

```bash
# Run interactive setup
./scripts/setup-grafana-cloud.sh

# Follow prompts to:
# 1. Create Grafana Cloud account (or use existing)
# 2. Get stack URL
# 3. Create access policy token
# 4. Configure endpoints
# 5. Add to Doppler
```

### Step 3: Configure Doppler

Add these secrets to Doppler (infrastructure project):

```bash
# Supabase PostgreSQL (from step 1)
AUTHENTIK_POSTGRES_HOST=db.xxxxx.supabase.co
AUTHENTIK_POSTGRES_NAME=postgres
AUTHENTIK_POSTGRES_USER=postgres
AUTHENTIK_POSTGRES_PASSWORD=your-password
AUTHENTIK_POSTGRES_PORT=5432

# Authentik secrets (generate these)
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60)
AUTHENTIK_BOOTSTRAP_PASSWORD=your-strong-admin-password
AUTHENTIK_BOOTSTRAP_TOKEN=$(openssl rand -hex 32)

# Grafana Cloud (from step 2)
GRAFANA_CLOUD_API_KEY=glc_your-token
GRAFANA_CLOUD_METRICS_URL=https://prometheus-prod-.../api/prom/push
GRAFANA_CLOUD_LOGS_URL=https://logs-prod-.../loki/api/v1/push
GRAFANA_CLOUD_TRACES_URL=https://tempo-prod-...:443

# Existing secrets (should already be there)
CLOUDFLARE_TUNNEL_TOKEN=...
ACME_EMAIL=...
```

### Step 4: Deploy

```bash
# Deploy everything
gh workflow run deploy-stack.yml

# Or manually:
# 1. Cloudflare
# 2. OCI
# 3. Authentik
# 4. oci-mgmt
```

### Step 5: Configure Backups

```bash
# SSH to VM
ssh -i ~/.ssh/oci-homelab ubuntu@<VM_IP>

# Add to crontab
crontab -e

# Add this line for daily backups at 2 AM:
0 2 * * * /opt/oci-core/scripts/backup-local-data.sh >> /var/log/homelab-backup.log 2>&1
```

## 📊 Architecture After Changes

```
┌─────────────────────────────────────────────────────────────┐
│                        USER                                  │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│              Cloudflare Access (Zero Trust)                  │
│                    Authentication Layer                      │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│                  Cloudflare Tunnel                           │
│                     (No open ports)                          │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│                    OCI VM (Free Tier)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Traefik    │  │  Authentik  │  │  Prometheus/Alloy   │  │
│  │  (Proxy)    │  │  (IdP)      │  │  (Monitoring)       │  │
│  └─────────────┘  └──────┬──────┘  └─────────────────────┘  │
│                          ↓                                   │
│                   Redis (local)                              │
└──────────────────────────┬───────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│              Supabase PostgreSQL (Cloud)                     │
│              ┌──────────────────────┐                        │
│              │ • Users              │                        │
│              │ • Groups             │                        │
│              │ • Policies           │                        │
│              │ • 500MB Free Tier    │                        │
│              │ • IP Restricted      │                        │
│              └──────────────────────┘                        │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│               Grafana Cloud (Observability)                  │
│              ┌──────────────────────┐                        │
│              │ • Metrics            │                        │
│              │ • Logs               │                        │
│              │ • Dashboards         │                        │
│              │ • Alerts             │                        │
│              └──────────────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

## 🔒 Security Improvements

1. **Database Isolation**: PostgreSQL outside VM with IP restrictions
2. **No Open Ports**: Cloudflare Tunnel means no exposed ports
3. **Authentication**: Cloudflare Access + Authentik (double layer)
4. **Encryption**: SSL everywhere (Tunnel, Supabase, Grafana)
5. **Secrets Management**: Doppler (no secrets in Git)

## 📈 Next Steps (Recommended)

### Immediate (This Week)
1. [ ] Run backup script and verify it works
2. [ ] Setup daily cron job for backups
3. [ ] Create OCI Object Storage bucket for backups
4. [ ] Test VM recreation with Supabase (verify data persists)

### Short Term (This Month)
1. [ ] Setup Grafana Cloud alerts for critical services
2. [ ] Create second OCI VM for high availability
3. [ ] Implement fail2ban on VM
4. [ ] Document incident response procedures

### Long Term (Next Quarter)
1. [ ] Migrate to Kubernetes (K3s)
2. [ ] Implement GitOps with ArgoCD
3. [ ] Multi-region deployment
4. [ ] Automated disaster recovery testing

## 💾 Data Persistence Matrix

| Data | Before | After | Survives VM Recreate? |
|------|--------|-------|----------------------|
| Authentik DB | Local VM | Supabase | ✅ Yes |
| Authentik Media | Local VM | Local VM + Backup | ✅ With backup restore |
| Prometheus | Local VM | Local VM + Backup | ✅ With backup restore |
| Traefik Certs | Local VM | Local VM + Backup | ✅ With backup restore |
| Redis | Local VM | Local VM | ✅ Stateless (cache only) |

## 🎉 Benefits Achieved

1. **Resilience**: Database survives VM recreation
2. **Automation**: CLI scripts for complex setup
3. **Monitoring**: Grafana Cloud integration
4. **Backups**: Automated daily backups
5. **Documentation**: Complete risk analysis
6. **Security**: IP-restricted database access

## 📞 Troubleshooting

### Supabase Connection Issues
```bash
# Test connection
psql "postgresql://postgres:password@db.xxxxx.supabase.co:5432/postgres" -c "SELECT 1;"

# Check IP restrictions in Supabase Dashboard
# Project Settings → Database → Network Restrictions
```

### Grafana Cloud No Data
```bash
# Check Alloy logs
docker logs oci-core-grafana-alloy-1

# Verify endpoints
curl -H "Authorization: Bearer $TOKEN" $METRICS_URL

# Check Doppler secrets
doppler secrets list -p infrastructure
```

### Backup Failures
```bash
# Check OCI CLI is configured
oci os ns get

# Run backup manually with debug
bash -x /opt/oci-core/scripts/backup-local-data.sh
```

## 📝 Files Summary

### Modified
- `docker/oci-core/docker-compose.yml` - Authentik + Supabase
- `doppler.yaml` - New secrets documentation

### Created
- `docs/RISK_ANALYSIS.md` - Risk analysis
- `scripts/setup-supabase-postgres.sh` - Supabase setup
- `scripts/setup-grafana-cloud.sh` - Grafana setup
- `scripts/backup-local-data.sh` - Backup automation
- `SUMMARY.md` (this file) - Changes overview

## ✅ Checklist

Before deploying:
- [ ] Supabase project created
- [ ] IP restrictions configured in Supabase
- [ ] Doppler secrets added
- [ ] Grafana Cloud account created
- [ ] Access policy token created
- [ ] Backup script tested
- [ ] Cron job configured

After deploying:
- [ ] Authentik accessible at auth.smadja.dev
- [ ] Services protected by Cloudflare Access
- [ ] Metrics flowing to Grafana Cloud
- [ ] Backups running successfully
- [ ] Test VM recreation procedure
