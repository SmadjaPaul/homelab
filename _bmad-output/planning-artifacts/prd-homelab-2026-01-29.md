---
date: 2026-01-29
author: PM Agent
project: homelab
version: 2.0
status: draft
lastUpdated: 2026-01-29
updateNotes: Align with Architecture v6.0 (Authentik as IdP ; validation manuelle ; design Authentik formalisé 2026-02-01 — session-travail-authentik.md §6)
inputDocuments:
  - product-brief-homelab-2026-01-21.md
  - architecture-proxmox-omni.md (v6.0)
  - session-travail-authentik.md (design Authentik à affiner avec agent PM)
previousVersion: prd-homelab-2026-01-22.md (v1.1)
---

# Product Requirements Document (PRD): Homelab Infrastructure

## Document Information

- **Project**: Homelab Infrastructure
- **Version**: 2.0
- **Date**: 2026-01-29
- **Status**: Draft
- **Author**: PM Agent
- **Architecture Version**: v6.0 (Proxmox + Omni + Talos + ArgoCD + **Authentik**)

## Executive Summary

This PRD defines the functional and non-functional requirements for a self-hosted homelab infrastructure solution designed to provide independence from GAFAM services while offering centralized storage, media streaming, gaming capabilities, and extensible local services. The solution is built on Infrastructure-as-Code (IaC) principles to enable AI-assisted maintainability and developer-friendly management workflows.

**Core Value Proposition**: AI-assisted maintainability through declarative infrastructure management, making the homelab as manageable as code rather than requiring deep system administration expertise.

**Target Users**: 
- Primary: Developer administrator (Paul) and graphic designer (non-technical power user)
- Secondary: Family members (5 people) for storage and media needs

### Hardware Resources

**Homelab Server** (Proxmox Host):
- **IP**: 192.168.68.51 (Proxmox Web UI: https://192.168.68.51:8006)
- **RAM**: 64GB
- **Storage**: 1TB SSD (system), 2x 20TB HDD (data)
- **GPU**: NVIDIA GPU (for gaming VMs)

**Oracle Cloud** (Always Free Tier):
- **Instances**: 2 ARM VMs (24GB RAM total, 4 OCPUs)
- **Storage**: 189GB block storage
- **Bandwidth**: 10 TB/month egress

### Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Hypervisor** | Proxmox VE | VM management, GPU passthrough |
| **Kubernetes OS** | Talos Linux | Immutable, API-only, minimal attack surface |
| **Cluster Management** | Omni (self-hosted) | Single pane of glass for all clusters |
| **GitOps** | ArgoCD | Continuous deployment, sync waves |
| **CNI** | Cilium | eBPF networking, Gateway API |
| **Storage** | ZFS + Longhorn | Data integrity + distributed K8s storage |
| **IaC** | Terraform + Ansible | VM provisioning + configuration |
| **Identity** | Authentik | SSO/OIDC/SAML for private services ; validation manuelle ; service accounts ; voir session-travail-authentik.md |
| **Ingress** | Cloudflare Tunnel | Zero-trust, no open ports |

### Architecture Overview

```
                    ┌─────────────────────────────────────┐
                    │      OMNI (Self-Hosted on OCI)      │
                    │  Single pane of glass for clusters  │
                    │  + Authentik SSO + Cloudflare Tunnel │
                    └─────────────────────────────────────┘
                                        │
           ┌────────────────────────────┼────────────────────────────┐
           │                            │                            │
           ▼                            ▼                            ▼
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   Proxmox (Home)    │    │   Proxmox (Home)    │    │   Oracle Cloud      │
│   DEV Cluster       │    │   PROD Cluster      │    │   CLOUD Cluster     │
│   ────────────────  │    │   ────────────────  │    │   ────────────────  │
│   • Minimal testing │    │   • Stable services │    │   • Family services │
│   • CI validation   │    │   • Gaming VMs      │    │   • External access │
│   • 4GB RAM total   │    │   • Local storage   │    │   • Omni management │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
           │                            │                            │
           └────────────────────────────┼────────────────────────────┘
                                        │
                               ┌────────┴────────┐
                               │   GitOps Repo   │
                               │   (This Repo)   │
                               └─────────────────┘
```

---

## 1. Functional Requirements (FRs)

### 1.1 Infrastructure Foundation

#### FR-001: Proxmox Hypervisor Setup
**Priority**: P0 (Critical)  
**Phase**: Phase 1 - Foundation

The system MUST provide Proxmox VE as the base hypervisor for all VMs.

**Requirements**:
- Proxmox VE installation and configuration
- Terraform provider (`bpg/proxmox`) for IaC VM provisioning
- ZFS storage pool configuration (2x 20TB HDD)
- GPU passthrough configuration for gaming VM
- Network bridge configuration (vmbr0)
- Web UI accessible at https://192.168.68.51:8006

**Acceptance Criteria**:
- Proxmox VE successfully installed and accessible
- Terraform can provision VMs via API
- ZFS pool operational with data integrity
- GPU passthrough tested and functional
- Network properly configured for VM access

---

#### FR-002: Talos Linux Kubernetes Clusters
**Priority**: P0 (Critical)  
**Phase**: Phase 1 - Foundation

The system MUST deploy Talos Linux for all Kubernetes nodes.

**Requirements**:
- Talos Linux VMs provisioned via Terraform
- DEV cluster: 1 combined control-plane/worker node (4GB RAM)
- PROD cluster: 1 control-plane + 1 worker node (16GB RAM total)
- CLOUD cluster: 2 nodes on Oracle Cloud (18GB RAM)
- Kubernetes v1.32.x on all clusters
- Talos v1.9.x on all nodes

**Acceptance Criteria**:
- All clusters operational and healthy
- `kubectl` access working via Omni kubeconfig
- Nodes immutable (no SSH access)
- Talos API accessible for management

---

#### FR-003: Omni Cluster Management
**Priority**: P0 (Critical)  
**Phase**: Phase 1 - Foundation

The system MUST deploy self-hosted Omni on Oracle Cloud for unified cluster management.

**Requirements**:
- Omni server deployed on oci-mgmt VM (Docker)
- PostgreSQL database for Omni state
- Authentik integration for SSO authentication (SAML for Omni)
- Cloudflare Tunnel for secure external access
- MachineClass definitions for node profiles
- ClusterTemplate definitions for declarative clusters

**Acceptance Criteria**:
- Omni UI accessible via Cloudflare Tunnel
- All three clusters visible and manageable
- SSO login working via Authentik
- Kubeconfig distribution functional
- Cluster upgrades manageable through Omni

---

#### FR-004: ArgoCD GitOps Deployment
**Priority**: P0 (Critical)  
**Phase**: Phase 1 - Foundation

The system MUST implement ArgoCD for GitOps continuous deployment.

**Requirements**:
- ArgoCD installed on PROD cluster (manages all clusters)
- ApplicationSets for dynamic app discovery
- Sync waves for ordered deployments (Wave 0-4)
- Multi-cluster deployment capability
- Self-management (ArgoCD manages its own config)
- SSO integration with Authentik

**Acceptance Criteria**:
- ArgoCD UI accessible and authenticated
- All clusters registered as deployment targets
- Sync waves executing in correct order
- Applications auto-sync from Git repository
- Rollback capability functional

---

#### FR-005: Storage Infrastructure
**Priority**: P0 (Critical)  
**Phase**: Phase 2 - Core Infrastructure

The system MUST provide multi-tier storage for all services.

**Requirements**:
- ZFS pool on Proxmox for VM disks and NFS
- Longhorn for Kubernetes distributed storage (PROD)
- local-path provisioner for DEV cluster
- NFS shares for media storage (12TB)
- Storage classes: `local-path`, `longhorn`, `nfs-media`

**Acceptance Criteria**:
- ZFS pool healthy with scrub schedule
- Longhorn operational on PROD cluster
- NFS accessible from Oracle Cloud via Twingate
- PVCs provisioning successfully
- Storage monitoring in place

---

### 1.2 Networking & Security

#### FR-006: Cilium CNI Deployment
**Priority**: P0 (Critical)  
**Phase**: Phase 1 - Foundation

The system MUST deploy Cilium as the CNI for all clusters.

**Requirements**:
- Cilium installed via ArgoCD (Wave 0)
- kube-proxy replacement enabled
- Gateway API support
- Hubble observability enabled
- Network policies for service isolation
- WireGuard encryption for inter-node traffic

**Acceptance Criteria**:
- Cilium operational on all clusters
- Network policies enforced
- Hubble metrics available
- Gateway API resources functional
- Inter-cluster communication secure

---

#### FR-007: Cloudflare Tunnel Integration
**Priority**: P0 (Critical)  
**Phase**: Phase 3 - PROD + Oracle Cloud

The system MUST expose services via Cloudflare Tunnel (zero open ports).

**Requirements**:
- Cloudflare Tunnel daemon on oci-mgmt VM
- Tunnel routes for all public services
- Cloudflare WAF + DDoS protection
- Per-service access policies
- DNS management via external-dns

**Acceptance Criteria**:
- No ports open on home router
- All services accessible via HTTPS
- Cloudflare protection active
- DNS records auto-managed
- Access policies enforced

---

#### FR-008: 2-Tier Authentication Strategy
**Priority**: P0 (Critical)  
**Phase**: Phase 3 - PROD + Oracle Cloud

The system MUST implement 2-tier authentication as defined in architecture and in the Authentik design (session-travail-authentik.md §6).

**Tier 1 - Private Data (Authentik SSO)**:
- Nextcloud, Immich, Vaultwarden, Baïkal, n8n
- oauth2-proxy for SSO enforcement
- Centralized identity management
- **User flow**: self-registration enabled ; no access to apps until admin validates (manual validation in Authentik) ; after validation, user is added to groups and gains access ; optional webhook triggers CI to provision accounts in apps (Nextcloud, Navidrome, etc.).

**Tier 2 - Media/Public (App-Native Auth)**:
- Navidrome, Komga, Romm, Audiobookshelf, Mealie, Invidious
- Built-in user management (playlists, progress tracking)
- Cloudflare access layer

**Acceptance Criteria**:
- Tier 1 services require Authentik login (validation manuelle avant accès ; design formalisé session-travail-authentik.md §6)
- Tier 2 services use native auth
- oauth2-proxy functional
- SSO session management working
- User roles properly enforced
- Admin apps (Authentik Admin, Omni, ArgoCD, Grafana, Prometheus, ntfy) not exposed to family users ; only group `admin` has access

---

#### FR-009: Secrets Management
**Priority**: P0 (Critical)  
**Phase**: Phase 2 - Core Infrastructure

The system MUST securely manage secrets for all services.

**Requirements**:
- External Secrets Operator deployed
- Phase 1: Bitwarden Secrets integration
- Phase 2 (optional): HashiCorp Vault migration
- No secrets in Git repository
- Secret rotation capability

**Acceptance Criteria**:
- ESO operational and syncing secrets
- Bitwarden integration functional
- Secrets not exposed in Git
- Services receiving secrets correctly
- GitGuardian CI check passing

---

#### FR-010: Zero Trust Network Access
**Priority**: P1 (High)  
**Phase**: Phase 3 - PROD + Oracle Cloud

The system MUST implement Twingate for Zero Trust VPN access.

**Requirements**:
- Twingate connector deployed on Oracle Cloud cluster
- NFS access from Oracle Cloud to Homelab
- Per-service access control
- No full network VPN required
- Works through NAT (no port forwarding)

**Acceptance Criteria**:
- Twingate connector operational
- NFS mounted on Oracle Cloud services
- Access control per resource
- No open ports on home network
- Family users can access NFS storage

---

### 1.3 Core Services

#### FR-011: Nextcloud Deployment
**Priority**: P0 (Critical)  
**Phase**: Phase 4 - Services MVP
**Location**: Oracle Cloud cluster

The system MUST provide Nextcloud as the primary storage solution.

**Requirements**:
- Nextcloud instance with Authentik SSO (Tier 1)
- Storage via NFS to Homelab (Twingate)
- User accounts for developer, graphic designer, family
- Mobile app support (iOS/Android)
- File sharing and collaboration

**Acceptance Criteria**:
- Nextcloud accessible via Cloudflare Tunnel
- SSO login working
- Files stored on Homelab NFS
- Mobile apps functional
- Performance: > 10 MB/s for large files

---

#### FR-012: Vaultwarden Password Manager
**Priority**: P0 (Critical)  
**Phase**: Phase 4 - Services MVP
**Location**: Oracle Cloud cluster

The system MUST provide Vaultwarden for family password management.

**Requirements**:
- Vaultwarden deployed with Authentik SSO (Tier 1)
- Family sharing capabilities
- Mobile and browser extensions
- Encrypted vault storage
- Backup integration

**Acceptance Criteria**:
- Vaultwarden accessible and functional
- SSO authentication working
- Family members can share passwords
- Browser extensions working
- Backups running

---

#### FR-013: Baïkal CalDAV/CardDAV
**Priority**: P0 (Critical)  
**Phase**: Phase 4 - Services MVP
**Location**: Oracle Cloud cluster

The system MUST provide Baïkal for calendar and contact sync.

**Requirements**:
- Baïkal deployed with Authentik SSO (Tier 1)
- CalDAV for calendar sync
- CardDAV for contact sync
- Mobile device integration
- Multi-user support

**Acceptance Criteria**:
- Calendar sync working on all devices
- Contact sync working
- SSO authentication functional
- Multiple calendars per user
- Sharing capabilities working

---

#### FR-014: Comet (Real-Debrid Addon)
**Priority**: P0 (Critical)  
**Phase**: Phase 4 - Services MVP
**Location**: Oracle Cloud cluster (STATIC IP REQUIRED)

The system MUST provide Comet addon for Stremio streaming.

**Requirements**:
- Comet deployed on Oracle Cloud (static public IP)
- Maximum uptime (family depends on this)
- Real-Debrid account integration
- Accessible from Stremio clients

**Acceptance Criteria**:
- Comet accessible from Stremio
- Static IP maintained (Real-Debrid requirement)
- High availability (>99%)
- Streaming performance acceptable

---

#### FR-015: Navidrome Music Streaming
**Priority**: P0 (Critical)  
**Phase**: Phase 4 - Services MVP
**Location**: Oracle Cloud cluster

The system MUST provide Navidrome for music streaming.

**Requirements**:
- Navidrome deployed with app-native auth (Tier 2)
- Storage via NFS to Homelab music library
- Subsonic API compatible
- Mobile app support
- Multiple user accounts with playlists

**Acceptance Criteria**:
- Music library accessible
- Streaming functional
- Playlists working per user
- Mobile apps working
- Lidarr integration for library management

---

#### FR-016: AdGuard Home DNS
**Priority**: P0 (Critical)  
**Phase**: Phase 4 - Services MVP
**Location**: Homelab PROD cluster

The system MUST provide network-wide DNS filtering and ad blocking.

**Requirements**:
- AdGuard Home deployed on PROD cluster
- DNS server for home network
- Ad blocking and filtering
- DoH/DoT support (native)
- Statistics and logging

**Acceptance Criteria**:
- DNS resolution working
- Ad blocking effective
- Admin interface accessible
- Network devices using AdGuard DNS
- DoH/DoT functional

---

#### FR-017: Home Assistant
**Priority**: P0 (Critical)  
**Phase**: Phase 4 - Services MVP
**Location**: Homelab PROD cluster

The system MUST provide Home Assistant for home automation.

**Requirements**:
- Home Assistant deployed on PROD cluster
- Local network access
- Device integrations
- Automation capabilities
- Mobile app support

**Acceptance Criteria**:
- Home Assistant operational
- Devices discoverable and controllable
- Automations functional
- Mobile app connected
- Local access working

---

#### FR-018: Media Library Services
**Priority**: P1 (High)  
**Phase**: Phase 4 - Services MVP
**Location**: Homelab PROD cluster

The system MUST provide media library management.

**Requirements**:
- Komga for comics/manga (app-native auth)
- Romm for ROM management (app-native auth)
- Audiobookshelf for audiobooks (app-native auth)
- Storage via local NFS
- Individual user accounts

**Acceptance Criteria**:
- All services operational
- Media libraries accessible
- User progress tracking working
- Mobile access functional
- NFS storage mounted

---

#### FR-019: Glance Family Dashboard
**Priority**: P1 (High)  
**Phase**: Phase 4 - Services MVP
**Location**: Oracle Cloud cluster

The system MUST provide a family-friendly dashboard.

**Requirements**:
- Glance deployed on Oracle Cloud
- Links to all family services
- Weather, calendar integrations
- Simple, intuitive interface
- No authentication required (behind Cloudflare)

**Acceptance Criteria**:
- Dashboard accessible
- All service links working
- Integrations functional
- Family members can use easily

---

### 1.4 Monitoring & Observability

#### FR-020: Prometheus Monitoring Stack
**Priority**: P0 (Critical)  
**Phase**: Phase 2 - Core Infrastructure
**Location**: Homelab PROD cluster

The system MUST provide comprehensive monitoring.

**Requirements**:
- Prometheus for metrics collection
- Grafana for visualization (admin dashboard)
- Loki for log aggregation
- Alloy (Grafana Agent) for collection
- ServiceMonitor resources for services

**Acceptance Criteria**:
- Prometheus scraping all services
- Grafana dashboards functional
- Logs aggregated in Loki
- Historical data retained
- Cross-cluster metrics (lightweight from Oracle Cloud)

---

#### FR-021: Alerting System
**Priority**: P0 (Critical)  
**Phase**: Phase 2 - Core Infrastructure

The system MUST provide automated alerting for critical issues.

**Requirements**:
- Alertmanager for alert routing
- ntfy for push notifications (self-hosted)
- Telegram bot for critical alerts
- Alert rules for: disk failure, service downtime, security incidents
- Alert prioritization and escalation

**Acceptance Criteria**:
- Alertmanager operational
- Mobile push notifications received
- Telegram alerts working
- Critical alerts immediate
- Warnings in digest format

---

### 1.5 CI/CD Pipeline

#### FR-022: GitHub Actions CI Pipeline
**Priority**: P0 (Critical)  
**Phase**: Phase 3 - PROD + Oracle Cloud

The system MUST validate all changes before deployment.

**Requirements**:
- Manifest validation (kubeval)
- YAML linting (yamllint)
- Security scanning (Trivy, Grype)
- Secret detection (GitGuardian)
- Automatic PR checks

**Acceptance Criteria**:
- CI runs on all PRs
- Validation catches errors
- Security issues flagged
- No secrets in commits
- Clear pass/fail feedback

---

#### FR-023: Dev/Prod Promotion Pipeline
**Priority**: P1 (High)  
**Phase**: Phase 3 - PROD + Oracle Cloud

The system MUST support staged deployments.

**Requirements**:
- Automatic deployment to DEV on push
- Stability validation period (24-48h)
- Manual or automatic promotion to PROD
- Rollback capability
- Deployment notifications

**Acceptance Criteria**:
- DEV receives changes first
- Validation period observed
- PROD promotion controlled
- Rollback tested
- Team notified of deployments

---

### 1.6 Backup & Disaster Recovery

#### FR-024: 3-2-1 Backup Strategy
**Priority**: P0 (Critical)  
**Phase**: Phase 2 - Core Infrastructure

The system MUST implement comprehensive backup following 3-2-1 rule.

**Requirements**:
- 3 copies: primary + local backup + offsite
- 2 media types: SSD/HDD + cloud
- 1 offsite: OVH Object Storage (3TB free)
- Velero for Kubernetes backup
- Restic/Volsync for file-level backup
- ZFS snapshots for point-in-time recovery

**Acceptance Criteria**:
- 3-2-1 rule implemented
- Automated backups running
- Backups encrypted
- Restoration tested monthly
- Recovery time < 4 hours for critical data

---

#### FR-025: Critical Data Classification
**Priority**: P0 (Critical)  
**Phase**: Phase 2 - Core Infrastructure

The system MUST support tagging critical data for priority backup.

**Requirements**:
- Critical: configs, databases, photos → cloud backup
- Non-critical: media files → local backup only
- Backup retention policies
- Bandwidth optimization (compression, deduplication)

**Acceptance Criteria**:
- Critical data identified and tagged
- Cloud backup running for critical data
- Local backup for all data
- Retention policies configured
- Bandwidth optimized

---

### 1.7 Gaming Infrastructure

#### FR-026: Windows Gaming VM
**Priority**: P2 (Medium)  
**Phase**: Phase 6 - Gaming & Advanced
**Location**: Proxmox direct (MVP), KubeVirt (future)

The system MUST provide Windows gaming capability.

**Requirements**:
- Windows VM on Proxmox (32GB RAM, 8 vCPU)
- GPU passthrough (NVIDIA)
- Remote access (Parsec, Moonlight, Steam Remote Play)
- On-demand startup (not always running)
- Storage access for games

**Acceptance Criteria**:
- Windows VM boots and runs games
- GPU passthrough functional
- Remote gaming working
- Performance acceptable (60 FPS medium settings)
- VM controllable via API/UI

---

#### FR-027: KubeVirt Integration (Future)
**Priority**: P3 (Low)  
**Phase**: Phase 6 - Gaming & Advanced

The system SHOULD support on-demand gaming via KubeVirt.

**Requirements**:
- KubeVirt for VM management in Kubernetes
- VM templates for instant startup
- Web interface to launch gaming sessions
- GeForce Now-style streaming experience

**Acceptance Criteria**:
- KubeVirt operational
- VMs launchable via K8s API
- Streaming functional
- User experience acceptable

---

### 1.8 Optional Services (Phase 5)

#### FR-028: Immich Photo Management
**Priority**: P2 (Medium)  
**Phase**: Phase 5 - Optional Services
**Location**: Oracle Cloud cluster

**Requirements**:
- Immich deployed with Authentik SSO
- Storage via NFS to Homelab
- Photo upload and organization
- Face recognition
- Mobile app support

---

#### FR-029: n8n Workflow Automation
**Priority**: P2 (Medium)  
**Phase**: Phase 5 - Optional Services
**Location**: Oracle Cloud cluster

**Requirements**:
- n8n deployed with Authentik SSO
- Workflow automation capabilities
- Integration with services
- Webhook support

---

#### FR-030: Mealie Recipe Management
**Priority**: P3 (Low)  
**Phase**: Phase 5 - Optional Services
**Location**: Oracle Cloud cluster

**Requirements**:
- Mealie deployed with app-native auth
- Recipe import and management
- Meal planning
- Shopping lists

---

#### FR-031: Invidious YouTube Frontend
**Priority**: P3 (Low)  
**Phase**: Phase 5 - Optional Services
**Location**: Oracle Cloud cluster

**Requirements**:
- Invidious deployed with app-native auth
- Privacy-focused YouTube access
- Subscriptions and playlists
- No Google tracking

---

## 2. Non-Functional Requirements (NFRs)

### 2.1 Performance Requirements

#### NFR-001: File Transfer Performance
**Priority**: P1 (High)

| Metric | Target |
|--------|--------|
| Local transfer | > 100 MB/s |
| Remote transfer (VPN) | > 10 MB/s |
| Media streaming | > 10 Mbps (1080p) |
| Concurrent users | 5 without degradation |

---

#### NFR-002: Service Response Time
**Priority**: P1 (High)

| Metric | Target |
|--------|--------|
| Web interface load | < 3 seconds |
| API response (p95) | < 500ms |
| Service startup | < 2 minutes |
| ArgoCD sync | < 5 minutes |

---

#### NFR-003: Gaming Performance
**Priority**: P2 (Medium) - Phase 6

| Metric | Target |
|--------|--------|
| Frame rate | 60 FPS (medium settings) |
| Remote latency | < 50ms |
| Game loading | Acceptable UX |

---

### 2.2 Reliability Requirements

#### NFR-004: System Uptime
**Priority**: P0 (Critical)

| Metric | Target |
|--------|--------|
| Monthly downtime | < 4 hours |
| Service availability | > 95% |
| Comet availability | > 99% (critical for family) |
| Auto-healing rate | > 70% |

---

#### NFR-005: Data Integrity
**Priority**: P0 (Critical)

| Metric | Target |
|--------|--------|
| ZFS data integrity | 100% (scrub verified) |
| Backup integrity | Verified monthly |
| Data corruption | Zero tolerance |

---

### 2.3 Security Requirements

#### NFR-006: Security Posture
**Priority**: P0 (Critical)

| Metric | Target |
|--------|--------|
| Critical vulnerabilities | Zero unpatched |
| Medium vulnerabilities | < 5 |
| Image scanning | 100% before deployment |
| Security incidents | < 2 per year |
| Critical patches applied | Within 7 days |
| All updates applied | Within 30 days |

---

#### NFR-007: Access Control
**Priority**: P0 (Critical)

| Metric | Target |
|--------|--------|
| Services behind auth | 100% |
| SSO coverage (Tier 1) | 100% |
| 2FA for critical services | Enabled |
| External access via tunnel | 100% |
| Open ports on home router | Zero |

---

### 2.4 Maintainability Requirements

#### NFR-008: Operational Efficiency
**Priority**: P0 (Critical)

| Metric | Target |
|--------|--------|
| Weekly maintenance | < 2 hours (after setup) |
| Add new service | < 15 minutes (recurrent) |
| Infrastructure changes | Trackable in Git |
| Documentation | Complete and current |

---

#### NFR-009: Infrastructure Complexity
**Priority**: P1 (High)

| Metric | Target |
|--------|--------|
| Complexity growth | < 20% per quarter |
| Service independence | Modular architecture |
| Technical debt | Tracked and managed |

---

### 2.5 Resource Allocation

#### NFR-010: Homelab Resource Usage
**Priority**: P1 (High)

| Mode | RAM Usage | Notes |
|------|-----------|-------|
| Normal operation | ~28GB | PROD active, DEV stopped, Gaming OFF |
| Testing mode | ~32GB | DEV + PROD, Gaming OFF |
| Gaming mode | ~48GB | Gaming VM + PROD, DEV stopped |
| Maximum | 64GB | All resources utilized |

---

#### NFR-011: Oracle Cloud Resource Usage
**Priority**: P1 (High)

| Component | RAM | OCPUs |
|-----------|-----|-------|
| Management VM (Omni, Authentik) | ~5GB | 1 |
| K8s Cluster MVP | ~12GB | 3 |
| Phase 2 additions | ~4GB | - |
| **Total** | ~19GB | 4 |

Must stay within Always Free limits (24GB RAM, 4 OCPUs).

---

### 2.6 Cost Requirements

#### NFR-012: Cost Efficiency
**Priority**: P1 (High)

| Metric | Target |
|--------|--------|
| Annual cost | < $1000 (after setup) |
| Cost savings vs cloud | > $500/year |
| Cloud backup cost | Optimized (compression) |
| Oracle Cloud | Always Free tier only |

---

## 3. User Stories

### 3.1 Developer Administrator (Paul)

| ID | Story |
|----|-------|
| US-001 | As a developer, I want to manage all clusters from a single Omni dashboard so I can see system health at a glance |
| US-002 | As a developer, I want ArgoCD to auto-deploy changes from Git so I can use familiar dev workflows |
| US-003 | As a developer, I want mobile push notifications for critical alerts so I'm aware of issues immediately |
| US-004 | As a developer, I want to add new services via Kustomize overlay in < 15 minutes |
| US-005 | As a developer, I want container image scanning to prevent deploying vulnerable images |
| US-006 | As a developer, I want Cloudflare Tunnel so I don't need to open ports on my home router |
| US-007 | As a developer, I want DEV cluster to validate changes before PROD deployment |
| US-008 | As a developer, I want comprehensive monitoring to proactively manage the system |

---

### 3.2 Graphic Designer (Non-Technical Power User)

| ID | Story |
|----|-------|
| US-009 | As a graphic designer, I want to access Nextcloud from any device to work anywhere |
| US-010 | As a graphic designer, I want to share files with clients securely via Nextcloud links |
| US-011 | As a graphic designer, I want fast file transfer (>10MB/s) for large design files |
| US-012 | As a graphic designer, I want automatic backup of my work so I don't lose files |
| US-013 | As a graphic designer, I want an intuitive interface without technical jargon |
| US-014 | As a graphic designer, I want SSO so I only login once for all services |
| US-015 | As a graphic designer, I want version history to recover previous file versions |

---

### 3.3 Family Members (Casual Users)

| ID | Story |
|----|-------|
| US-016 | As a family member, I want Stremio streaming via Comet to always be available |
| US-017 | As a family member, I want Navidrome to stream my music with personal playlists |
| US-018 | As a family member, I want simple Nextcloud access for photo backup |
| US-019 | As a family member, I want Vaultwarden for secure password sharing |
| US-020 | As a family member, I want Glance dashboard to find all services easily |
| US-021 | As a family member, I want privacy for my data (separate from other family) |
| US-022 | As a family member, I want mobile access for all services |

---

## 4. Service Catalog Summary

### 4.1 By Location

**Oracle Cloud - Management VM (Docker)**:
- Omni, Authentik, PostgreSQL, Cloudflare Tunnel, Nginx

**Oracle Cloud - Kubernetes Cluster**:
- Media: Comet, Navidrome, Lidarr
- Critical: Vaultwarden, Baïkal, Twingate, oauth2-proxy
- Collaborative: Nextcloud
- Dashboard: Glance
- Optional: Immich, n8n, Mealie, Invidious

**Homelab - PROD Cluster**:
- Home: AdGuard Home, Home Assistant, Audiobookshelf, Komga, Romm
- Monitoring: Prometheus, Grafana, Loki, Alertmanager, Alloy, ntfy

**Homelab - DEV Cluster**:
- Same manifests as PROD (reduced resources via overlay)
- Ephemeral testing only

---

### 4.2 By Authentication Tier

**Tier 1 - Authentik SSO** (Private Data):
- Nextcloud, Immich, Vaultwarden, Baïkal, n8n

**Tier 2 - App-Native** (Media/Public):
- Navidrome, Komga, Romm, Audiobookshelf, Mealie, Invidious, Glance

---

## 5. Success Criteria

### 5.1 Phase 1-2 Success (Foundation + Core)

| Criterion | Target |
|-----------|--------|
| Clusters operational | DEV + PROD + CLOUD |
| Omni managing all clusters | Single pane of glass |
| ArgoCD auto-deploying | Sync waves working |
| Monitoring active | Prometheus + Grafana |
| Backup running | 3-2-1 implemented |

---

### 5.2 Phase 3-4 Success (Services MVP)

| Criterion | Target |
|-----------|--------|
| Critical services running | Nextcloud, Vaultwarden, Baïkal, Comet |
| SSO functional | Authentik + oauth2-proxy |
| Family adoption | Active usage > 20 days/month |
| Uptime | > 95% (Comet > 99%) |
| Security | Zero critical vulnerabilities |

---

### 5.3 Overall 6-Month Success

| Criterion | Target |
|-----------|--------|
| Operational time | < 2 hours/week |
| Add service time | < 15 minutes |
| Monthly downtime | < 4 hours |
| User adoption | All family members active |
| Cost | < $1000/year |
| GAFAM independence | > 90% critical data self-hosted |

---

## 6. Implementation Phases

| Phase | Name | Key Deliverables |
|-------|------|------------------|
| 1 | Foundation | Proxmox VMs, Omni, DEV cluster, ArgoCD, Cilium |
| 2 | Core Infrastructure | Storage, cert-manager, external-dns, ESO, Monitoring, AdGuard |
| 3 | PROD + Oracle Cloud | PROD cluster, OCI infra, Authentik, Cloudflare Tunnel, Twingate, CI/CD |
| 4 | Services MVP | Critical + Collaborative + Media + Home + Dashboard |
| 5 | Optional Services | Immich, n8n, Mealie, Invidious |
| 6 | Gaming & Advanced | GPU passthrough, Windows VM, KubeVirt, Backup automation |

---

## 7. Out of Scope

The following are explicitly out of scope for MVP:

1. **Multi-node control planes** - Single control plane per cluster sufficient
2. **High availability with failover** - Manual recovery acceptable
3. **Advanced CI/CD** - Basic promotion pipeline sufficient
4. **Enterprise features** - No need for multi-tenancy, advanced RBAC
5. **Advanced analytics** - Basic Grafana dashboards sufficient
6. **Frigate/NVR** - Deferred to future phases
7. **Mail server** - Use existing email provider

---

## 8. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Hardware failure | 3-2-1 backup, ZFS data integrity, monitoring |
| Data loss | Automated backups, encryption, monthly restore tests |
| Security compromise | Talos immutable OS, Cloudflare WAF, scanning, no open ports |
| Service unavailability | Monitoring, alerting, auto-healing |
| Oracle Cloud tier changes | Monitor usage, stay within limits |
| Complexity creep | IaC approach, modular architecture, documentation |
| User adoption failure | User-friendly interfaces, documentation, gradual rollout |
| Comet IP issues | Oracle Cloud static IP, monitoring uptime |

---

## 9. Open Questions

1. Specific domain name requirements (subdomains for services)?
2. Cloudflare account tier (free vs pro)?
3. Bitwarden Secrets vs direct Vault for Phase 1?
4. Gaming VM resource allocation vs other services?
5. Family member onboarding order and timeline?

---

## 10. Appendix

### 10.1 Glossary

| Term | Definition |
|------|------------|
| ArgoCD | GitOps continuous deployment tool for Kubernetes |
| Cilium | eBPF-based CNI for Kubernetes networking |
| ESO | External Secrets Operator |
| GitOps | Git-based infrastructure management workflow |
| Kustomize | Kubernetes native configuration management |
| Omni | Sidero Labs' Talos cluster management platform |
| Sync Wave | ArgoCD ordered deployment mechanism |
| Talos Linux | Immutable, API-only Kubernetes OS |
| Twingate | Zero Trust network access solution |

### 10.2 Identity Design (Authentik) — Summary

Design formalisé le 2026-02-01 ; mises à jour 2026-02-01 (invitation-only, trafic Cloudflare). Détail dans `session-travail-authentik.md` §6 et `decision-invitation-only-et-acces-cloudflare.md`.

| Thème | Décision |
|-------|----------|
| **Flux utilisateur** | **Invitation uniquement** : self-registration désactivée ; onboarding par lien d’invitation (UI ou API Authentik). Pas d’accès aux apps tant que l’utilisateur n’est pas dans les groupes autorisés ; provisionnement optionnel via webhook → CI. |
| **Trafic utilisateur** | **Toutes les connexions utilisateurs** (auth, portail Authentik, apps protégées) **passent par Cloudflare** (Tunnel) ; pas d’accès direct à l’origine pour les utilisateurs finaux. |
| **Apps famille** | Nextcloud, Vaultwarden, Baïkal, Navidrome, Mealie, Glance, Immich, n8n — exposées via Cloudflare ; portail « My applications » pour utilisateurs validés (groupes). |
| **Apps admin** | Authentik Admin, Omni, ArgoCD, Grafana, Prometheus, Alertmanager, ntfy (admin) — non exposées aux utilisateurs famille ; accès réservé au groupe `admin`. |
| **CI** | Invitations créées en UI ou via API ; provisionnement par webhook Authentik (recommandé) ou job manuel ; job CI « valider user » optionnel (API Authentik). |
| **Service accounts** | ci-github, argocd, backup, n8n ; définis en Terraform (provider goauthentik/authentik) ; secrets dans Bitwarden/ESO. |

### 10.3 References

- Product Brief: `product-brief-homelab-2026-01-21.md`
- Architecture: `architecture-proxmox-omni.md` (v6.0)
- Identity design: `session-travail-authentik.md` (§6 Décisions prises), `decision-invitation-only-et-acces-cloudflare.md`
- Inspired repos: qjoly/GitOps, ravilushqa/homelab, mitchross/talos-argocd-proxmox, Mafyuh/iac, ahinko/home-ops

---

## Document Approval

- **Status**: Draft
- **Next Steps**: Review, then proceed to Epics & Stories creation
- **Reviewers**: Project stakeholders
- **Approval Date**: TBD

---

*End of Product Requirements Document v2.0*
