I used Docker exclusively for many years before learning Kubernetes, and I still rely on it regularly, especially for testing new images, since it's simple to get things running.

When a containerized service proves useful and becomes part of my routine, I migrate it to Kubernetes—_if_ it's feasible to do so.

That said, some services like **Jellyfin** will likely remain on Docker permanently, as it uses a dedicated GPU on a standalone host that isn't practical to add to the Kubernetes cluster. Additionally, some complex multi-container applications like **Kasm** or **Wazuh** are either unstable on Kubernetes or lack proper support, making Docker the better option for those.

## 📁 Folder Structure

- Each subfolder contains a `docker-compose.yml` or `compose.yaml` file for a specific service or stack.
- Custom Dockerfiles for CI/CD and utility images are in [`Dockerfiles/`](Dockerfiles/README.md).
- Secrets and environment variable mappings are managed via **Doppler**.

## 🔐 Secrets Management with Doppler

Secrets are managed via **Doppler** and injected at runtime using the Doppler CLI.

### Quick Start

```bash
# Install Doppler CLI
brew install doppler

# Login
doppler login

# Run any service
./doppler-compose.sh arm up -d
```

### Doppler Projects

- `infrastructure` - Core infra secrets (Cloudflare, Twingate, Proxmox, Unifi)
- `databases` - Database passwords (PostgreSQL, MySQL, MongoDB, MinIO)
- `apps` - Application secrets (Gitea, Jellyfin, Media stack, etc.)
- `monitoring` - Monitoring secrets (SMTP, alerts)

### Manual Usage

```bash
cd arm
doppler run --project apps --config arm -- docker compose up -d
```

## 🚀 Services

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

See [doppler.yaml](../doppler.yaml) for complete secret configuration.
