# Homelab Infrastructure

Personal homelab running on Proxmox VE with Kubernetes (Talos Linux), managed via GitOps with Flux CD.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                 │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                ┌─────────▼─────────┐
                │   Cloudflare      │
                │   (DNS, WAF,      │
                │    Tunnel)        │
                └─────────┬─────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
┌───────▼───────┐ ┌───────▼───────┐ ┌───────▼───────┐
│   Proxmox     │ │  Oracle Cloud │ │  Oracle Cloud │
│   (On-prem)   │ │  (ARM VMs)    │ │  (ARM VMs)    │
│               │ │  ARM           │ │  DB-Server    │
└───────┬───────┘ └───────┬───────┘ └───────┬───────┘
        │                 │                 │
        └─────────────────┴─────────────────┘
                          │
                ┌─────────▼─────────┐
                │   Talos Linux     │
                │   (3 Control      │
                │    Plane nodes)   │
                │                   │
                │   ┌─────────────┐ │
                │   │ Kubernetes  │ │
                │   │  (Flux CD)  │ │
                │   └─────────────┘ │
                └───────────────────┘
```

## Components

### Infrastructure
| Component | Purpose | Location |
|-----------|---------|----------|
| Proxmox VE | Hypervisor | On-premises |
| Oracle Cloud | ARM VMs (Free Tier) | eu-paris-1 |
| Cloudflare | DNS, WAF, Tunnel | Cloud |
| Twingate | Zero Trust VPN | Cloud |
| Unifi | Network management | On-prem |

### Kubernetes Stack
| Component | Purpose |
|-----------|---------|
| Talos Linux | Immutable K8s OS |
| Flux CD | GitOps continuous delivery |
| Cilium | eBPF CNI and networking |
| External Secrets | Doppler integration |
| Cert Manager | Let's Encrypt certificates |
| Rook-Ceph | Distributed storage |

### Docker Services
Services that run better on Docker (GPU, complex multi-container):

| Service | Description | Host |
|---------|-------------|------|
| **Jellyfin** | Media server with GPU transcoding | Ark-Ripper |
| **Kasm** | Browser isolation workspaces | ARM |
| **Wazuh** | SIEM and security monitoring | Dedicated |
| **Blocky** | DNS with ad-blocking | HA setup |
| **Databases** | MySQL, PostgreSQL, MinIO | DB-Server |
| **NPM** | Nginx Proxy Manager | Proxy |

### Kubernetes Applications
| App | Description |
|-----|-------------|
| **Cert Manager** | TLS certificate management |
| **Cilium** | CNI, network policies, observability |
| **External Secrets** | Doppler secrets sync |
| **Grafana** | Monitoring dashboards |
| **Prometheus** | Metrics collection |
| **Loki** | Log aggregation |
| **Authentik** | Identity provider / SSO |
| **Homepage** | Dashboard |

## Quick Start

### Prerequisites

```bash
# Install CLI tools
brew install terraform kubectl helm talosctl doppler

# Install OCI CLI
brew install oci-cli
```

### 1. Doppler Setup

```bash
# Login to Doppler
doppler login

# Verify projects exist
doppler projects

# Expected projects: infrastructure, databases, apps, monitoring
```

### 2. Deploy Infrastructure

```bash
# Oracle Cloud Infrastructure
cd terraform/oracle
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init && terraform apply

# Cloudflare DNS
cd terraform/cloudflare
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# Proxmox VMs
cd terraform/proxmox
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
```

### 3. Bootstrap Kubernetes

```bash
# Generate Talos config
cd kubernetes/talos
talhelper genconfig

# Apply to nodes
talosctl apply-config --insecure -n <node-ip> --file clusterconfig/talos-controlplane-1.yaml

# Bootstrap Flux
cd ../..
kubectl create ns flux-system
kubectl -n flux-system create secret generic sops-age --from-file=age.agekey=/home/$USER/.sops/key.txt
kubectl apply -f kubernetes/flux/cluster.yaml

# Setup Doppler token for External Secrets
kubectl create secret generic doppler-token-auth \
  --from-literal=dopplerToken='dp.st.xxxxxx' \
  -n external-secrets
```

### 4. Run Docker Services

```bash
cd docker

# Example: Start ARM stack
./doppler-compose.sh arm up -d

# Example: Start databases
./doppler-compose.sh db-server up -d

# View all options
./doppler-compose.sh --help
```

## Directory Structure

```
homelab/
├── ansible/              # Ansible playbooks and roles
├── docker/               # Docker Compose services
│   ├── arm/              # ARM Oracle VM services
│   ├── databases/        # MySQL, PostgreSQL, MinIO
│   ├── jellyfin/         # Media server
│   ├── wazuh/            # SIEM
│   └── ...
├── kubernetes/           # Kubernetes manifests (Flux)
│   ├── apps/             # Applications
│   ├── cluster/          # Cluster-wide resources
│   ├── flux/             # Flux configuration
│   └── talos/            # Talos configs
├── packer/               # VM templates (Ubuntu)
├── terraform/            # Infrastructure as Code
│   ├── authentik/
│   ├── cloudflare/
│   ├── oracle/
│   ├── proxmox/
│   ├── servarr/
│   ├── twingate/
│   └── unifi/
├── .taskfiles/           # Task commands
├── doppler.yaml          # Doppler secret configuration
└── Taskfile.yaml         # Task runner config
```

## Secrets Management

All secrets are managed via **Doppler**:

- **Doppler Projects**:
  - `infrastructure` - Cloudflare, Twingate, Proxmox, Unifi
  - `databases` - PostgreSQL, MySQL, MongoDB passwords
  - `apps` - Application secrets (Gitea, Jellyfin, etc.)
  - `monitoring` - SMTP, alerting credentials

- **Kubernetes**: External Secrets Operator syncs Doppler secrets
- **Docker**: Doppler CLI injects secrets at runtime
- **Ansible**: Doppler CLI retrieves secrets during playbook runs

See [doppler.yaml](doppler.yaml) for complete secret mapping.

## Cost

**Total: ~$5/month** (mostly free tier)

| Service | Tier | Cost |
|---------|------|------|
| Oracle Cloud | Always Free | $0 |
| Cloudflare | Free | $0 |
| Doppler | Free (200 secrets) | $0 |
| GitHub | Free | $0 |
| Twingate | Free | $0 |
| Proton VPN | Plus | ~$5/mo |

## Workflows

- **Docker CD** - Deploys Docker services on push
- **Ansible Playbooks** - Runs Ansible on schedule or manual trigger
- **Renovate** - Automated dependency updates
- **Trivy** - Container vulnerability scanning

## Useful Commands

```bash
# Task commands
task --list                    # List all tasks
task talos:genconfig          # Generate Talos configs
task talos:apply              # Apply Talos configs
task helm:install EXTERNAL-SECRET # Install External Secrets

# Kubernetes
kubectl get kustomizations -A  # View Flux status
kubectl get helmreleases -A    # View Helm releases
flux reconcile source git flux-system  # Force sync

# Docker
cd docker && ./doppler-compose.sh <service> logs -f
```

## Credits

Based on the excellent work by:
- [Mafyuh/iac](https://github.com/Mafyuh/iac) - Main inspiration
- [MacroPower/homelab](https://github.com/MacroPower/homelab) - External Secrets with Doppler
- [onedr0p/flux-cluster-template](https://github.com/onedr0p/flux-cluster-template) - Flux patterns
