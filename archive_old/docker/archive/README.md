# Archived Docker Services

This directory contains Docker services that are no longer used in the active homelab deployment.

## ⚠️ IMPORTANT

**DO NOT DELETE** these directories without first:
1. Checking if any data needs to be migrated
2. Verifying no active containers are using these images
3. Creating backups of any persistent volumes

## 📦 Archived Services

### Legacy Infrastructure
- **oci-core/** - Old monolithic Docker Compose setup (replaced by modular architecture)

### Media & Entertainment
- **jellyfin/** - Media server (Jellyfin)
- **downloaders/** - Download management stack

### Networking & DNS
- **caddy/** - Caddy reverse proxy (replaced by Traefik)
- **npm/** - Nginx Proxy Manager (replaced by Traefik)
- **blocky/** - DNS server with ad-blocking

### Security & Monitoring (Legacy)
- **wazuh/** - Wazuh SIEM stack
- **alloy/** - Grafana Alloy (moved to monitoring/)
- **exporters/** - Prometheus exporters (moved to monitoring/)

### Platform Specific
- **arm/** - ARM architecture specific services (for ARM Oracle VMs)

## 🔄 Migration Guide

If you need to restore any of these services:

```bash
# Move back from archive
cd docker
mv archive/<service-name> ./

# Update docker-compose if needed
cd <service-name>
docker-compose up -d
```

## 🗑️ Safe Deletion Checklist

Before deleting any archived service:

- [ ] No running containers use these images
  ```bash
  docker ps -a | grep <service-name>
  ```

- [ ] No persistent volumes contain important data
  ```bash
  docker volume ls | grep <service-name>
  ```

- [ ] No external dependencies on these services
  - Check other docker-compose.yml files
  - Verify no hardcoded references in scripts

- [ ] Data backed up (if applicable)
  ```bash
  # Example for PostgreSQL
  docker exec <db-container> pg_dump -U <user> <db> > backup.sql
  ```

## 📊 Current Active Services

See `docker/README.md` for the current active services.

## 📝 History

**Date Archived:** 2026-02-15
**Reason:** Migration to modular Docker architecture
- Services organized by function (core, authentik, monitoring, services/)
- Each service has its own docker-compose.yml
- Shared external Docker networks
- Doppler secrets management

## 🆘 Need Help?

If you're unsure about deleting a service:
1. Check the service documentation in its original location
2. Review `docs/MIGRATION_GUIDE.md`
3. Ask in the project discussions
