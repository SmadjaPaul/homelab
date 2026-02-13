# Risk Analysis - Homelab Architecture

## Executive Summary

This document analyzes the risks associated with the current homelab architecture and provides mitigation strategies.

## Current Architecture

```
User → Cloudflare Access → Authentik (IdP) → Cloudflare Tunnel → OCI VM → Traefik → Services
                                    ↓
                              Supabase PostgreSQL (cloud)
```

## Risk Matrix

| Risk | Severity | Likelihood | Impact | Mitigation Priority |
|------|----------|------------|--------|---------------------|
| Single VM Failure | High | Medium | High | **Critical** |
| Database Loss | Critical | Low | Critical | **Critical** |
| Cloudflare Tunnel Down | High | Low | High | **High** |
| Secrets Exposure | Critical | Low | Critical | **Critical** |
| VM Recreation Data Loss | High | High | High | **Critical** |
| Auth Provider Down | High | Low | High | **High** |
| Monitoring Blindness | Medium | Medium | Medium | **Medium** |
| Network Compromise | High | Low | High | **High** |

## Detailed Risk Analysis

### 1. Single Point of Failure (OCI VM) 🔴 CRITICAL

**Risk**: All services run on a single VM. If it fails, everything is down.

**Impact**: Complete service outage

**Current Mitigation**:
- VM recreated via Terraform (IaC)
- Docker Compose for fast redeployment
- Data in Supabase (survives VM recreation)

**Recommended Mitigations**:
1. **Multi-AZ deployment**:
   - Deploy 2 OCI VMs in different availability zones
   - Use Traefik with multiple backends
   - Database already external (Supabase)

2. **Load balancer**:
   - Cloudflare Load Balancing ($5/month)
   - Health checks on both VMs
   - Automatic failover

3. **Backup strategy**:
   - Daily VM snapshots (OCI)
   - Configuration in Git (already done ✓)

### 2. Database Loss 🔴 CRITICAL

**Risk**: Supabase PostgreSQL data loss (though unlikely)

**Impact**: Complete loss of user accounts, authentication data

**Current Mitigation**:
- Supabase managed service (they handle backups)
- Free tier includes automated backups

**Recommended Mitigations**:
1. **Export users regularly**:
   ```bash
   # Script to export Authentik users
   pg_dump $AUTHENTIK_POSTGRES_URI > authentik-backup-$(date +%Y%m%d).sql
   ```

2. **Store backups in OCI Object Storage**:
   ```bash
   oci os object put --bucket-name backups --file authentik-backup.sql
   ```

3. **Test restore procedure** monthly

### 3. VM Recreation Destroys Local Data 🔴 CRITICAL

**Risk**: Recreating VM loses Prometheus data, Traefik certs, Authentik media

**Impact**:
- Loss of metrics history (Prometheus)
- Let's Encrypt rate limits (if too many cert requests)
- Loss of uploaded files/media in Authentik

**Current Mitigation**:
- PostgreSQL moved to Supabase ✓
- Redis is stateless (cache only)

**Recommended Mitigations**:

1. **Persist Prometheus data to OCI Block Volume**:
   ```yaml
   volumes:
     - oci-block-volume/prometheus:/prometheus
   ```

2. **Backup Let's Encrypt certificates**:
   ```bash
   # Backup script
   tar czf certs-backup.tar.gz data/traefik/letsencrypt
   oci os object put --bucket-name backups --file certs-backup.tar.gz
   ```

3. **Authentik media files**:
   ```yaml
   # Use OCI Object Storage via rclone/s3fs
   volumes:
     - type: bind
       source: /mnt/oci-object-storage/media
       target: /media
   ```

### 4. Secrets Exposure 🔴 CRITICAL

**Risk**: Doppler token or secrets leaked

**Impact**: Attacker gains full access to infrastructure

**Current Mitigation**:
- Doppler service tokens (good)
- Secrets not in Git (good)
- Doppler has audit logs

**Recommended Mitigations**:

1. **Rotate secrets regularly**:
   ```bash
   # Monthly rotation
   doppler configs tokens delete old-token
   doppler configs tokens create --config prd new-token
   ```

2. **Use short-lived tokens in CI**:
   - Create token at workflow start
   - Delete at workflow end

3. **Enable Doppler access logs**:
   - Monitor for unusual access patterns

### 5. Cloudflare Tunnel Down 🔴 HIGH

**Risk**: Tunnel disconnected, services unreachable

**Impact**: Complete external access loss

**Current Mitigation**:
- Docker restart policy
- Verification step in deploy workflow

**Recommended Mitigations**:

1. **Health checks**:
   ```bash
   # Add to crontab on VM
   */5 * * * * /opt/oci-core/scripts/health-check.sh
   ```

2. **Backup VPN**:
   - Twingate or Tailscale as fallback
   - Direct access if needed

3. **Multiple tunnels** (advanced):
   - Different Cloudflare accounts
   - Geographic distribution

### 6. Authentication Provider Down 🔴 HIGH

**Risk**: Authentik unavailable

**Impact**: Cannot authenticate to services

**Current Mitigation**:
- Cloudflare Access provides fallback email auth
- Supabase database is managed (high availability)

**Recommended Mitigations**:

1. **Enable email fallback in Cloudflare Access**:
   ```hcl
   # terraform/cloudflare/modules/access/main.tf
   # Already configured ✓
   ```

2. **Authentik health monitoring**:
   - Uptime check on auth.smadja.dev
   - Alert if down > 2 minutes

3. **Disaster recovery plan**:
   - Document manual bypass procedure
   - Keep emergency admin credentials secure

### 7. Monitoring Blindness 🟡 MEDIUM

**Risk**: Cannot detect failures or performance issues

**Impact**: Slow response to incidents

**Current State**: Grafana Cloud configured (Grafana Alloy)

**Recommended Mitigations**:

1. **Set up alerts**:
   - VM CPU > 80%
   - Memory > 85%
   - Disk > 90%
   - Services down

2. **Grafana OnCall** (free tier available):
   - Route alerts to email/Slack
   - On-call rotation if team grows

3. **External monitoring**:
   - UptimeRobot (free) or Healthchecks.io
   - Checks from multiple locations

### 8. Network Compromise 🔴 HIGH

**Risk**: Unauthorized access to VM or services

**Impact**: Data breach, service takeover

**Current Mitigation**:
- Cloudflare Access (auth before reaching VM)
- No open ports (Tunnel only)
- SSH key-based auth

**Recommended Mitigations**:

1. **Fail2ban** on VM:
   ```bash
   sudo apt install fail2ban
   # Configure for SSH
   ```

2. **Regular security updates**:
   ```bash
   # Add to Ansible playbook
   apt upgrade -y
   ```

3. **Audit logs**:
   - Forward SSH logs to Grafana Cloud
   - Monitor for brute force attempts

4. **Network restrictions**:
   - Supabase: IP whitelist (OCI VM only) ✓
   - Doppler: IP restrictions if possible

## Data Persistence Strategy

### Current State

| Data | Location | Survives VM Recreate? | Backup? |
|------|----------|----------------------|---------|
| Authentik DB | Supabase | ✅ Yes | Supabase managed |
| Authentik Media | Local VM | ❌ No | ❌ No |
| Prometheus Metrics | Local VM | ❌ No | ❌ No |
| Traefik Certs | Local VM | ❌ No | ❌ No |
| Redis Cache | Local VM | ✅ Yes (stateless) | N/A |

### Recommended Improvements

1. **Short term** (immediate):
   ```bash
   # Create backup script
   scripts/backup-local-data.sh

   # Run daily via cron
   0 2 * * * /opt/oci-core/scripts/backup-local-data.sh
   ```

2. **Medium term** (this week):
   - Mount OCI Block Volume for persistent data
   - Automated backup to OCI Object Storage

3. **Long term** (next month):
   - Multi-VM deployment
   - Kubernetes migration (K3s)
   - GitOps with ArgoCD

## Incident Response Plan

### Scenario 1: VM Crash

```
1. Terraform recreates VM (5 min)
2. Ansible deploys Docker + Doppler (3 min)
3. Docker Compose starts services (2 min)
4. Authentik connects to Supabase (existing data)
5. Restore local data from backup (if needed)
Total downtime: ~10 minutes
```

### Scenario 2: Database Corruption

```
1. Restore from Supabase backup (UI or API)
2. Or: restore from OCI Object Storage backup
3. Verify Authentik functionality
4. Communicate to users if needed
```

### Scenario 3: Secrets Compromised

```
1. Rotate all secrets immediately
2. Revoke old Doppler tokens
3. Regenerate Cloudflare tokens
4. Update GitHub secrets
5. Redeploy everything
6. Audit logs for unauthorized access
```

## Compliance & Best Practices

### Security
- [x] No secrets in Git
- [x] Service tokens for automation
- [x] HTTPS everywhere
- [x] Authentication required for internal services
- [ ] Regular security audits (quarterly)
- [ ] Penetration testing (annually)

### Backup
- [x] IaC (Terraform) for infrastructure
- [x] Docker Compose for services
- [x] External database (Supabase)
- [ ] Automated local data backup
- [ ] Backup testing procedure
- [ ] Documented recovery time (RTO)

### Monitoring
- [x] Grafana Cloud for metrics
- [x] Health checks in CI/CD
- [ ] Alerting rules (in progress)
- [ ] On-call rotation (if team grows)
- [ ] Incident response runbooks

## Action Items

### Immediate (This Week)
1. [ ] Create backup script for local data
2. [ ] Setup OCI Block Volume for persistence
3. [ ] Configure backup to OCI Object Storage
4. [ ] Document recovery procedures

### Short Term (This Month)
1. [ ] Setup Grafana Cloud alerts
2. [ ] Deploy second OCI VM (staging)
3. [ ] Implement fail2ban
4. [ ] Create incident response runbooks

### Long Term (Next Quarter)
1. [ ] Kubernetes migration (K3s)
2. [ ] Multi-region deployment
3. [ ] Automated disaster recovery testing
4. [ ] Security audit

## Conclusion

The architecture is **moderately resilient** with room for improvement. The move to Supabase PostgreSQL significantly reduces data loss risk. Priority should be given to:

1. **Backup strategy** for local data
2. **Multi-VM deployment** for high availability
3. **Alerting** for proactive incident response

The current setup is suitable for a small business but should be enhanced as the business grows.
