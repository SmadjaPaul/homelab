I used Docker exclusively for many years before learning Kubernetes, and I still rely on it regularly, especially for testing new images, since it's simple to get things running.

When a containerized service proves useful and becomes part of my routine, I migrate it to Kubernetes—_if_ it's feasible to do so.

That said, some services like **Jellyfin** will likely remain on Docker permanently, as it uses a dedicated GPU on a standalone host that isn't practical to add to the Kubernetes cluster. Additionally, some complex multi-container applications like **Kasm** or **Wazuh** are either unstable on Kubernetes or lack proper support, making Docker the better option for those.

## 🆕 NEW: Modular Architecture (2026-02-15)

The docker directory has been restructured for better modularity and maintainability:

```
docker/
├── core/                 # Traefik + Cloudflared (reverse proxy & tunnel)
├── authentik/           # Authentik SSO + PostgreSQL local + Redis
├── monitoring/          # Prometheus + Grafana Alloy
├── services/            # Individual application services
│   ├── comet/          # Stremio addon (direct IP, no tunnel)
│   ├── nextcloud/      # (to be added)
│   └── gitea/          # (to be added)
└── scripts/            # Backup and utility scripts
```

### Key Improvements

- ✅ **PostgreSQL local** - No more external Aiven dependency
- ✅ **Modular structure** - One service per directory
- ✅ **Doppler integration** - `doppler run -- docker-compose up` (no .env files)
- ✅ **External networks** - Shared Docker networks between services
- ✅ **Comet without tunnel** - Direct IP access for streaming
- ✅ **Automated backups** - PostgreSQL backup script with rclone support

### Quick Start (New Structure)

```bash
# 1. Setup networks
./docker-stack.sh start core

# 2. Start all services
./docker-stack.sh start all

# Or manually
doppler run -p infrastructure -c prd -- docker-compose up -d
```

See [docker/README_NEW.md](README_NEW.md) for complete documentation.

## 📁 Folder Structure

### Legacy Structure (still functional)

- Each subfolder contains a `docker-compose.yml` or `compose.yaml` file for a specific service or stack.
- Custom Dockerfiles for CI/CD and utility images are in [`Dockerfiles/`](Dockerfiles/README.md).
- Secrets and environment variable mappings are managed via **Doppler**.

### New Modular Structure

- `core/` - Core infrastructure (Traefik, Cloudflared)
- `authentik/` - Identity provider (Authentik, PostgreSQL, Redis)
- `monitoring/` - Monitoring stack (Prometheus, Grafana Alloy)
- `services/` - Application services (Comet, etc.)
- `scripts/` - Backup and management scripts

## 🔐 Secrets Management with Doppler

Secrets are managed via **Doppler** and injected at runtime using the Doppler CLI.

### Quick Start

```bash
# Install Doppler CLI
brew install doppler

# Login
doppler login

# Run any service (legacy)
./doppler-compose.sh arm up -d

# Or new modular approach
cd authentik
doppler run -p infrastructure -c prd -- docker-compose up -d
```

### Doppler Projects

- `infrastructure` - Core infra secrets (Cloudflare, Authentik, Comet)
- `databases` - Database passwords (legacy)
- `apps` - Application secrets (Gitea, Jellyfin, Media stack, etc.)
- `monitoring` - Monitoring secrets (Grafana Cloud)

### Recommended: Doppler run injection

Instead of creating `.env` files, inject secrets directly:

```yaml
# docker-compose.yml
services:
  app:
    environment:
      # Only list variable names
      - API_KEY
      - DATABASE_URL
```

```bash
# Run with Doppler injection
doppler run -p infrastructure -c prd -- docker-compose up -d
```

Benefits:
- ✅ Secrets never touch disk (no .env files)
- ✅ Centralized management
- ✅ Instant updates when secrets change
- ✅ Audit logs and access control

See [DOPPLER_INTEGRATION.md](DOPPLER_INTEGRATION.md) for detailed setup.

## 🚀 Services

### Core Infrastructure

| Service | Description | Location |
|---------|-------------|----------|
| **core** | Traefik + Cloudflared | `core/` |
| **authentik** | SSO with PostgreSQL local | `authentik/` |
| **monitoring** | Prometheus + Grafana Alloy | `monitoring/` |

### Legacy Services

| Service | Description |
|---------|-------------|
| **arm** | Gitea, Gotify, Homepage (ARM Oracle VM) |
| **db-server** | MySQL, PostgreSQL, MinIO, pgAdmin |
| **blocky** | DNS server with ad-blocking |
| **jellyfin** | Media server with GPU transcoding |
| **kasm** | Kasm Workspaces |
| **wazuh** | Wazuh SIEM |
| **npm** | Nginx Proxy Manager |
| **proxy** | Caddy reverse proxy |
| **ollama** | Ollama AI/LLM |
| **ubu** | Media stack (Sonarr, Radarr, Bazarr) |
| **alloy** | Grafana Alloy collectors |
| **exporters** | Prometheus exporters |
| **omni** | Sidero Omni |
| **oci-core** | Legacy OCI stack |

### New Services

| Service | Description | Access |
|---------|-------------|--------|
| **comet** | Stremio addon with Real-Debrid | Direct IP (no tunnel) |

## 🔄 Migration Guide

### From legacy to new structure:

1. **Setup Doppler project** `infrastructure` with all secrets
2. **Create Docker networks**:
   ```bash
   docker network create traefik-public
   docker network create authentik-private
   docker network create monitoring
   docker network create streaming
   ```
3. **Deploy core services** in order:
   - `core/` (Traefik + Cloudflared)
   - `authentik/` (wait for healthy)
   - `monitoring/`
   - `services/comet/`

4. **Migrate data** if needed from legacy PostgreSQL

## 🛠️ Management

```bash
# Using management script
./docker-stack.sh start all
./docker-stack.sh stop authentik
./docker-stack.sh logs core -f
./docker-stack.sh backup

# Or manually
cd authentik
doppler run -p infrastructure -c prd -- docker-compose up -d
```

## 💾 Backup

```bash
# Automated backup script
cd scripts
./backup.sh all

# Or specific service
./backup.sh authentik

# Restore
./backup.sh restore authentik_20240215_120000.sql.gz authentik-postgresql
```

## 📚 Documentation

- [DOPPLER_INTEGRATION.md](DOPPLER_INTEGRATION.md) - Doppler setup guide
- [README_NEW.md](README_NEW.md) - New modular architecture
- [Architecture Comparison](../docs/ARCHITECTURE_COMPARISON.md)
- [Streaming Architecture](../GOAL_STREAMING.md)

See [doppler.yaml](../doppler.yaml) for complete secret configuration.
