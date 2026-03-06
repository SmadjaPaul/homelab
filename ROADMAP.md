# 🗺️ Roadmap Homelab

## 🌟 Version 1.0 (✅ Completed)

The V1.0 of the platform established the core architecture, identity, and standard services.

### Core Infrastructure
- [x] OCI Cluster Deployment (OKE)
- [x] Doppler Configuration for Secrets
- [x] Pulumi-based GitOps deployment (`k8s-core`, `k8s-storage`, `k8s-apps`)
- [x] External Secrets Operator integration
- [x] Storage Provisioning (Hetzner Storage Box via SMB, Oracle Free Tier S3)

### Identity & Access (Secure Zero Trust)
- [x] Cloudflare Tunnel implementation (No open inbound ports)
- [x] Envoy Gateway Ingress configuration
- [x] Authentik migration (Replaced Auth0)
- [x] Global OIDC auto-provisioning across services
- [x] Email/SMTP via Migadu for SSO recovery

### Core Services
- [x] Homepage (Dashboard)
- [x] CloudNativePG (PostgreSQL Operator)
- [x] Redis (Caching Layer)
- [x] Vaultwarden (Password Management & OIDC Integrations)
- [x] n8n (Automation Workflows)
- [x] Navidrome (Streaming Audio / Replaced Lidarr & Audiobookshelf as test)
- [x] Soulseek (P2P Client)

---

## 🚀 Version 2.0 (Plan & In Progress)

The next major iteration focuses on Observability, comprehensive Media management, and expanding Business apps.

### 1. Observability & Monitoring
- [ ] Deploy Grafana Agent / k8s-monitoring
- [ ] Connect Prometheus remote write to Grafana Cloud
- [ ] Deploy centralized logging (Loki)
- [ ] Configure essential alerting to Discord/Slack for system degradation

### 2. Family & Home Management
- [ ] **Nextcloud**: File syncing, calendars, contacts.
- [ ] **Immich**: Photo backup (requires substantial local storage; potentially wait for Home Cluster).
- [ ] **Paperless-ngx**: Document OCR and archiving.
- [ ] Restructure Media stack (Radarr, Sonarr, Prowlarr) for fully automated consumption.

### 3. Home Cluster (Talos) Integration
- [ ] Provision Proxmox server physically at home.
- [ ] Deploy Talos Linux Single Node Cluster (SNC).
- [ ] Federation: Connect Home Cluster to OCI Hub.
- [ ] Migrate heavy storage workloads (Jellyfin/Immich) to the Home Cluster.

### 4. Backups & Disaster Recovery
- [ ] Configure Velero for cluster-state backups.
- [ ] Ensure all PostgreSQL databases (CNPG) are backing up via WAL to S3.
- [ ] Schedule regular Restic backups for PVCs containing non-database state.

---

## 💡 Wishlist (To Evaluate)

- **Gitea/Forgejo**: Self-hosted code repositories (if GitHub becomes undesirable).
- **Outline**: Team wiki and system documentation.
- **Kestra**: High-performance automation as a code-first alternative to n8n.
- **Dify**: Private LLM interactions and RAG over personal documents.

---

## 📜 Architectural Decisions

### ✅ Validated (V1.0)
- **OCI OKE** for the cloud cluster hub (generous free tier).
- **Pulumi** over Flux CD (Better type-safety, dynamic generation, Python ecosystem).
- **Doppler** for centralized secrets management.
- **Authentik** for Auth (Superior to Auth0 for self-hosting with deep proxy capabilities).
- **Cloudflare** for DNS, Edge WAF, and Tunnels.

---

*Note: For the technical deployment steps, refer to `docs/DEPLOYMENT.md`.*
