# Architecture Homelab

## Vue d'ensemble

Architecture hybride **hub-and-spoke** avec cluster OCI (cloud) et cluster Home (local).

```
                    Internet
                       │
                       ▼
              ┌────────────────┐
              │  Cloudflare    │
              │  (DNS/WAF)     │
              └───────┬────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
        ▼             ▼             ▼
┌──────────┐  ┌────────────┐  ┌────────────┐
│ VM-Hub   │  │ Cluster    │  │ Cluster    │
│ Omni     │  │ OCI        │  │ Home       │
│ (4GB)    │  │ (Talos)    │  │ (Talos)    │
└──────────┘  └────────────┘  └────────────┘
     │              │               │
     └──────────────┴───────────────┘
              VPN (Tailscale)
```

## Cluster OCI (Public)

### VMs

| VM | Rôle | Specs | IP Privée |
|----|------|-------|-----------|
| omni-hub | Control Plane Omni | 2 CPU, 4GB | 10.0.1.2 |
| talos-cp-1 | Control Plane K8s | 2 CPU, 6GB | 10.0.1.10 |
| talos-w-1 | Worker K8s | 2 CPU, 6GB | 10.0.1.11 |
| talos-w-2 | Worker K8s | 2 CPU, 6GB | 10.0.1.12 |

### Namespaces

```
infra/
├── external-secrets    # Sync Doppler
├── cert-manager       # TLS certificates
├── traefik            # Ingress controller
├── authentik          # Identity provider
└── cloudflare-tunnel  # Secure tunnel

pro/                    # Business services
├── nextcloud          # File sync
├── gitea              # Git hosting
├── vaultwarden        # Password manager
├── odoo               # ERP (planned)
├── fleetdm            # MDM (planned)
└── snipe-it           # ITAM (planned)

perso/                  # Personal/Family
├── matrix             # Chat
├── immich             # Photos
└── homepage           # Dashboard
```

### Flux d'Authentification

```
Utilisateur
    │
    ▼
Cloudflare Access ──► Email auth (famille)
    │
    ▼
Authentik ──► SSO + MFA (pro)
    │
    ▼
Service (Nextcloud, Gitea, etc.)
```

## Cluster Home (Local)

### Infrastructure

| Ressource | Usage |
|-----------|-------|
| Proxmox VE | Hypervisor |
| TrueNAS | Stockage 28TB |
| Talos VMs | Kubernetes |

### Namespaces

```
media/
├── jellyfin           # Video streaming (GPU)
├── immich             # Photos (principal)
└── navidrome          # Music

iot/
├── home-assistant     # Smart home
└── adguard-home       # DNS filtering

tools/
├── gitea              # Git local
└── n8n                # Automation
```

## Sécurité

### Layers

1. **Cloudflare**: WAF, DDoS protection, Access
2. **Tunnel**: Pas d'exposition directe des services
3. **Authentik**: SSO, MFA, policies
4. **Network Policies**: Isolation namespace
5. **Pod Security**: Restricted par défaut

### Secrets

```
Doppler (Source of Truth)
    │
    ▼
External Secrets Operator
    │
    ▼
Kubernetes Secrets
    │
    ▼
Applications
```

## Networking

### OCI VCN

```
VCN: 10.0.0.0/16
├── Subnet Public: 10.0.1.0/24
│   ├── Omni Hub: 10.0.1.2
│   └── Talos nodes: 10.0.1.10-12
└── Subnet Private: 10.0.2.0/24 (future)
```

### VPN

- **Tailscale** pour accès admin
- **Cloudflare Tunnel** pour services publics
- **Wireguard** backup

## Storage

### OCI

- **Block Storage**: Boot volumes
- **Object Storage**: Backups (S3-compatible)
- **Rook-Ceph**: Distributed storage (planned)

### Home

- **TrueNAS**: NFS shares
- **Longhorn**: Block storage K8s
- **Kopia**: Backup vers B2

## Monitoring

### Stack

- **Grafana Cloud**: Metrics, logs, traces
- **Prometheus**: Local metrics
- **Loki**: Local logs
- **Uptime Kuma**: Health checks

### Alertes

```
Critical ──► Email + Slack
Warning ───► Slack only
Info ──────► Grafana only
```

## Backup Strategy

### 3-2-1 Rule

- **3** copies des données
- **2** médias différents
- **1** offsite

### Implementation

```
Source ──► Kopia (local) ──► Backblaze B2 (offsite)
         │
         └───► OCI Object Storage (cloud)
```
