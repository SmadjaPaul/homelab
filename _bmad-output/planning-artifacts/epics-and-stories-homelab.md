---
date: 2026-01-29
author: PM Agent
project: homelab
version: 1.0
status: draft
lastUpdated: 2026-01-29
inputDocuments:
  - prd-homelab-2026-01-29.md (v2.0)
  - architecture-proxmox-omni.md (v4.0)
---

# Epics and Stories: Homelab Infrastructure

## Document Information

- **Project**: Homelab Infrastructure
- **Version**: 1.0
- **Date**: 2026-01-29
- **PRD Version**: 2.0
- **Architecture Version**: 4.0 (Proxmox + Omni + ArgoCD)

## Overview

This document breaks down the PRD into implementable epics and user stories, organized by the 6-phase implementation roadmap. Each story includes acceptance criteria and maps to specific functional requirements.

### Phase Summary

| Phase | Name | Epics | Stories | Priority |
|-------|------|-------|---------|----------|
| 1 | Foundation | 4 | 16 | P0 - Critical |
| 2 | Core Infrastructure | 4 | 14 | P0 - Critical |
| 3 | PROD + Oracle Cloud | 4 | 12 | P0 - Critical |
| 4 | Services MVP | 5 | 18 | P0/P1 - Critical/High |
| 5 | Optional Services | 1 | 4 | P2/P3 - Medium/Low |
| 6 | Gaming & Advanced | 2 | 6 | P2/P3 - Medium/Low |
| **Total** | | **20** | **70** | |

---

## Phase 1: Foundation

### Epic 1.1: Proxmox Hypervisor Setup
**Priority**: P0 (Critical)  
**FR Reference**: FR-001  
**Description**: Install and configure Proxmox VE as the base hypervisor for all homelab VMs.

#### Story 1.1.1: Install Proxmox VE
**As a** developer administrator  
**I want** Proxmox VE installed on the homelab server  
**So that** I can manage VMs through a web interface

**Acceptance Criteria**:
- [ ] Proxmox VE installed on AOOSTAR WTR MAX 8845
- [ ] Web UI accessible at https://192.168.68.51:8006
- [ ] Root password configured securely
- [ ] Network interface (vmbr0) configured for VM bridging

**Technical Notes**:
- Use latest Proxmox VE 8.x ISO
- Configure static IP: 192.168.68.51

---

#### Story 1.1.2: Configure ZFS Storage Pool
**As a** developer administrator  
**I want** ZFS storage configured on the HDDs  
**So that** data has integrity protection and snapshots

**Acceptance Criteria**:
- [ ] ZFS pool created from 2x 20TB HDDs (mirror or single with regular backups)
- [ ] `local-zfs` storage available in Proxmox
- [ ] Automatic scrub schedule configured (weekly)
- [ ] ZFS ARC cache allocated (~8GB)
- [ ] Email alerts configured for ZFS events

**Technical Notes**:
- Consider mirror vs single disk based on backup strategy
- Leave headroom for ZFS overhead

---

#### Story 1.1.3: Configure GPU Passthrough
**As a** developer administrator  
**I want** GPU passthrough configured  
**So that** I can use the NVIDIA GPU in gaming VMs

**Acceptance Criteria**:
- [ ] IOMMU enabled in BIOS
- [ ] VFIO modules loaded in Proxmox
- [ ] GPU isolated from host
- [ ] GPU available for VM assignment
- [ ] Passthrough tested with test VM

**Technical Notes**:
- Add `intel_iommu=on` or `amd_iommu=on` to kernel params
- Blacklist nouveau/nvidia drivers on host

---

#### Story 1.1.4: Setup Terraform Provider
**As a** developer administrator  
**I want** Terraform configured to manage Proxmox  
**So that** I can provision VMs via Infrastructure as Code

**Acceptance Criteria**:
- [ ] `bpg/proxmox` Terraform provider configured
- [ ] API token created for Terraform
- [ ] Provider connection tested
- [ ] Basic VM creation via Terraform works
- [ ] Terraform state stored securely

**Technical Notes**:
- Create dedicated API token with minimal permissions
- Store token in environment variable or secrets manager

---

### Epic 1.2: Talos Linux DEV Cluster
**Priority**: P0 (Critical)  
**FR Reference**: FR-002  
**Description**: Deploy a minimal DEV Kubernetes cluster using Talos Linux for CI validation.

#### Story 1.2.1: Create Talos VM via Terraform
**As a** developer administrator  
**I want** a Talos Linux VM provisioned via Terraform  
**So that** the DEV cluster infrastructure is reproducible

**Acceptance Criteria**:
- [ ] Terraform module for Talos VM created
- [ ] VM specs: 2 vCPU, 4GB RAM, 50GB storage
- [ ] Talos ISO attached/booted
- [ ] VM tagged: `talos`, `kubernetes`, `dev`
- [ ] Network configured on vmbr0

**Technical Notes**:
- Use `proxmox_virtual_environment_vm` resource
- Download Talos ISO or use Packer template

---

#### Story 1.2.2: Bootstrap DEV Cluster
**As a** developer administrator  
**I want** the DEV Kubernetes cluster bootstrapped  
**So that** I can deploy workloads for testing

**Acceptance Criteria**:
- [ ] Talos configuration generated via `talosctl`
- [ ] Machine config applied to VM
- [ ] Control plane bootstrapped
- [ ] Kubernetes API accessible
- [ ] `kubectl get nodes` shows node Ready

**Technical Notes**:
- Combined control-plane + worker (single node)
- Talos v1.9.x, Kubernetes v1.32.x

---

#### Story 1.2.3: Configure Talos Machine Config
**As a** developer administrator  
**I want** Talos machine config stored in Git  
**So that** cluster configuration is version controlled

**Acceptance Criteria**:
- [ ] Machine config YAML in `omni/clusters/dev.yaml`
- [ ] Secrets encrypted or externalized
- [ ] Config includes Cilium CNI settings
- [ ] Config includes cluster name and endpoint

**Technical Notes**:
- Use SOPS for secret encryption if needed
- Reference Omni ClusterTemplate format

---

### Epic 1.3: Omni Cluster Management
**Priority**: P0 (Critical)  
**FR Reference**: FR-003  
**Description**: Deploy self-hosted Omni on Oracle Cloud for unified cluster management.

#### Story 1.3.1: Provision Oracle Cloud Management VM
**As a** developer administrator  
**I want** a management VM on Oracle Cloud  
**So that** I can host Omni and supporting services externally

**Acceptance Criteria**:
- [ ] OCI VM created: 1 OCPU, 6GB RAM, 50GB storage
- [ ] Ubuntu or Oracle Linux installed
- [ ] Docker installed
- [ ] Static public IP assigned
- [ ] SSH access configured (key-based only)

**Technical Notes**:
- Use Terraform `oci` provider
- Always Free tier ARM shape: VM.Standard.A1.Flex

---

#### Story 1.3.2: Deploy Omni Server
**As a** developer administrator  
**I want** Omni deployed on the management VM  
**So that** I can manage all Talos clusters from one place

**Acceptance Criteria**:
- [ ] Omni container running
- [ ] PostgreSQL database configured
- [ ] Omni accessible via HTTPS
- [ ] Initial admin account created
- [ ] License key configured (if required)

**Technical Notes**:
- Use Docker Compose in `docker/oci-mgmt/`
- Follow Sidero Labs self-hosted guide

---

#### Story 1.3.3: Register DEV Cluster with Omni
**As a** developer administrator  
**I want** the DEV cluster registered in Omni  
**So that** I can manage it through the Omni dashboard

**Acceptance Criteria**:
- [ ] Omni agent installed on DEV cluster
- [ ] Cluster visible in Omni UI
- [ ] Node health displayed
- [ ] Kubeconfig downloadable from Omni
- [ ] Cluster upgrades manageable via Omni

**Technical Notes**:
- Use Omni join token for cluster registration
- Verify bi-directional connectivity

---

#### Story 1.3.4: Configure MachineClasses
**As a** developer administrator  
**I want** MachineClass definitions for node profiles  
**So that** I can declaratively define node specifications

**Acceptance Criteria**:
- [ ] `control-plane` MachineClass defined
- [ ] `worker` MachineClass defined
- [ ] `gpu-worker` MachineClass defined (for future)
- [ ] MachineClasses stored in `omni/machine-classes/`

**Technical Notes**:
- Define CPU, RAM, storage, labels
- Reference in ClusterTemplate

---

### Epic 1.4: ArgoCD GitOps Setup
**Priority**: P0 (Critical)  
**FR Reference**: FR-004  
**Description**: Install ArgoCD for GitOps continuous deployment.

#### Story 1.4.1: Install ArgoCD on DEV Cluster
**As a** developer administrator  
**I want** ArgoCD installed on the DEV cluster  
**So that** I can test GitOps workflows

**Acceptance Criteria**:
- [ ] ArgoCD installed via manifest
- [ ] ArgoCD UI accessible
- [ ] Admin password configured
- [ ] ArgoCD namespace created

**Technical Notes**:
- Use official ArgoCD install manifest
- Initial install via kubectl, then self-managed

---

#### Story 1.4.2: Configure Repository Connection
**As a** developer administrator  
**I want** ArgoCD connected to the Git repository  
**So that** it can sync applications from Git

**Acceptance Criteria**:
- [ ] Git repository added to ArgoCD
- [ ] SSH key or token configured for auth
- [ ] Repository sync working
- [ ] Webhook configured for instant sync (optional)

**Technical Notes**:
- Use deploy key with read-only access
- Configure in ArgoCD ConfigMap or UI

---

#### Story 1.4.3: Create Root Application
**As a** developer administrator  
**I want** a root Application that manages all other apps  
**So that** ArgoCD is self-managing (App of Apps pattern)

**Acceptance Criteria**:
- [ ] Root Application created in `kubernetes/base/argocd/root.yaml`
- [ ] Root app points to ApplicationSets directory
- [ ] ArgoCD manages its own configuration
- [ ] Changes to Git trigger sync

**Technical Notes**:
- App of Apps pattern for self-management
- Root app should have auto-sync enabled

---

#### Story 1.4.4: Configure Sync Waves
**As a** developer administrator  
**I want** sync waves configured for ordered deployment  
**So that** dependencies are installed before dependents

**Acceptance Criteria**:
- [ ] Wave 0: Cilium, MetalLB, cert-manager, ESO
- [ ] Wave 1: Storage (Longhorn/local-path)
- [ ] Wave 2: external-dns, Gateway API, databases
- [ ] Wave 3: Monitoring stack
- [ ] Wave 4: User applications

**Technical Notes**:
- Use `argocd.argoproj.io/sync-wave` annotation
- Define in ApplicationSets

---

#### Story 1.4.5: Create ApplicationSets
**As a** developer administrator  
**I want** ApplicationSets for dynamic app discovery  
**So that** new services are automatically deployed

**Acceptance Criteria**:
- [ ] Infrastructure ApplicationSet (Wave 0-1)
- [ ] Core ApplicationSet (Wave 2)
- [ ] Monitoring ApplicationSet (Wave 3)
- [ ] Apps ApplicationSet (Wave 4)
- [ ] ApplicationSets in `kubernetes/base/argocd/apps/`

**Technical Notes**:
- Use Git directory generator
- Filter by cluster labels

---

### Epic 1.5: Cilium CNI Deployment
**Priority**: P0 (Critical)  
**FR Reference**: FR-006  
**Description**: Deploy Cilium as the CNI for all clusters.

#### Story 1.5.1: Deploy Cilium on DEV Cluster
**As a** developer administrator  
**I want** Cilium deployed as the CNI  
**So that** pods have networking and security policies

**Acceptance Criteria**:
- [ ] Cilium installed via ArgoCD (Wave 0)
- [ ] kube-proxy replacement enabled
- [ ] Hubble enabled for observability
- [ ] Cilium status healthy
- [ ] Pod networking functional

**Technical Notes**:
- Use Helm chart via ArgoCD
- Configure in Talos machine config or ArgoCD values

---

#### Story 1.5.2: Configure Gateway API
**As a** developer administrator  
**I want** Gateway API configured  
**So that** I can use modern ingress patterns

**Acceptance Criteria**:
- [ ] Gateway API CRDs installed
- [ ] Cilium Gateway API enabled
- [ ] HTTPRoute resources working
- [ ] TLS termination functional

**Technical Notes**:
- Gateway API is the future of Ingress
- Supports multiple gateways per cluster

---

---

## Phase 2: Core Infrastructure

### Epic 2.1: Storage Infrastructure
**Priority**: P0 (Critical)  
**FR Reference**: FR-005  
**Description**: Deploy storage solutions for Kubernetes workloads.

#### Story 2.1.1: Deploy local-path Provisioner
**As a** developer administrator  
**I want** local-path storage provisioner on DEV  
**So that** I can test PVC workflows with minimal resources

**Acceptance Criteria**:
- [ ] local-path-provisioner deployed
- [ ] `local-path` StorageClass created
- [ ] PVC provisioning working
- [ ] Set as default StorageClass for DEV

**Technical Notes**:
- Rancher's local-path-provisioner
- Minimal overhead, suitable for testing

---

#### Story 2.1.2: Configure NFS Storage Class
**As a** developer administrator  
**I want** NFS storage accessible from Kubernetes  
**So that** services can access the media library

**Acceptance Criteria**:
- [ ] NFS server configured on Proxmox/ZFS
- [ ] NFS shares exported: `/media/films`, `/media/music`, etc.
- [ ] `nfs-media` StorageClass created
- [ ] PVCs can mount NFS volumes

**Technical Notes**:
- Use NFS CSI driver or static PVs
- 12TB media storage available

---

### Epic 2.2: Certificate Management
**Priority**: P0 (Critical)  
**FR Reference**: FR-007 (part)  
**Description**: Deploy cert-manager for automatic TLS certificates.

#### Story 2.2.1: Deploy cert-manager
**As a** developer administrator  
**I want** cert-manager installed  
**So that** TLS certificates are automatically managed

**Acceptance Criteria**:
- [ ] cert-manager deployed via ArgoCD (Wave 0)
- [ ] CRDs installed
- [ ] cert-manager pods healthy
- [ ] Certificate issuance working

**Technical Notes**:
- Use Helm chart
- Will use Cloudflare DNS01 challenge

---

#### Story 2.2.2: Configure ClusterIssuers
**As a** developer administrator  
**I want** Let's Encrypt ClusterIssuers configured  
**So that** certificates are automatically renewed

**Acceptance Criteria**:
- [ ] `letsencrypt-staging` ClusterIssuer created
- [ ] `letsencrypt-prod` ClusterIssuer created
- [ ] Cloudflare API token configured for DNS01
- [ ] Test certificate issued successfully

**Technical Notes**:
- Use DNS01 challenge (works with Cloudflare Tunnel)
- Store Cloudflare token in secret

---

### Epic 2.3: External DNS & Secrets
**Priority**: P0 (Critical)  
**FR Reference**: FR-009  
**Description**: Deploy external-dns and External Secrets Operator.

#### Story 2.3.1: Deploy external-dns
**As a** developer administrator  
**I want** external-dns to manage DNS records  
**So that** service DNS is automatically updated

**Acceptance Criteria**:
- [ ] external-dns deployed via ArgoCD (Wave 2)
- [ ] Cloudflare provider configured
- [ ] DNS records created for ingress resources
- [ ] TTL and sync interval configured

**Technical Notes**:
- Use Cloudflare API token
- Filter by annotation or ingress class

---

#### Story 2.3.2: Deploy External Secrets Operator
**As a** developer administrator  
**I want** ESO deployed for secrets management  
**So that** secrets are not stored in Git

**Acceptance Criteria**:
- [ ] ESO deployed via ArgoCD (Wave 0)
- [ ] CRDs installed
- [ ] ESO pods healthy

**Technical Notes**:
- Foundation for Phase 1 secrets strategy
- Supports multiple secret backends

---

#### Story 2.3.3: Configure Bitwarden SecretStore
**As a** developer administrator  
**I want** Bitwarden configured as the secret backend  
**So that** I can use my existing Bitwarden for secrets

**Acceptance Criteria**:
- [ ] Bitwarden SecretStore resource created
- [ ] Connection to Bitwarden API working
- [ ] ExternalSecret resources syncing
- [ ] Test secret created and verified

**Technical Notes**:
- Use Bitwarden Secrets Manager API
- Alternative: Bitwarden CLI approach

---

### Epic 2.4: Monitoring Stack
**Priority**: P0 (Critical)  
**FR Reference**: FR-020, FR-021  
**Description**: Deploy comprehensive monitoring and alerting.

#### Story 2.4.1: Deploy Prometheus
**As a** developer administrator  
**I want** Prometheus deployed for metrics collection  
**So that** I can monitor cluster and service health

**Acceptance Criteria**:
- [ ] Prometheus deployed via ArgoCD (Wave 3)
- [ ] ServiceMonitor CRDs installed
- [ ] Prometheus scraping cluster metrics
- [ ] Retention configured (15 days default)
- [ ] Storage configured (Longhorn PVC on PROD)

**Technical Notes**:
- Use kube-prometheus-stack Helm chart
- Configure for multi-cluster (federation later)

---

#### Story 2.4.2: Deploy Grafana
**As a** developer administrator  
**I want** Grafana deployed for visualization  
**So that** I can view dashboards and metrics

**Acceptance Criteria**:
- [ ] Grafana deployed via ArgoCD (Wave 3)
- [ ] Prometheus data source configured
- [ ] Default dashboards imported
- [ ] Admin password configured
- [ ] SSO integration ready (for Phase 3)

**Technical Notes**:
- Part of kube-prometheus-stack
- Admin dashboard for developer only

---

#### Story 2.4.3: Deploy Loki
**As a** developer administrator  
**I want** Loki deployed for log aggregation  
**So that** I can search and analyze logs

**Acceptance Criteria**:
- [ ] Loki deployed via ArgoCD (Wave 3)
- [ ] Loki data source in Grafana
- [ ] Logs queryable via LogQL
- [ ] Retention configured

**Technical Notes**:
- Use Loki-stack or standalone
- Alloy/Promtail for log collection

---

#### Story 2.4.4: Deploy Alloy (Grafana Agent)
**As a** developer administrator  
**I want** Alloy deployed for metric/log collection  
**So that** data is shipped to Prometheus/Loki

**Acceptance Criteria**:
- [ ] Alloy DaemonSet deployed
- [ ] Metrics forwarded to Prometheus
- [ ] Logs forwarded to Loki
- [ ] Node metrics collected

**Technical Notes**:
- Replaces Promtail + node_exporter
- Unified collection agent

---

#### Story 2.4.5: Deploy Alertmanager
**As a** developer administrator  
**I want** Alertmanager deployed for alert routing  
**So that** I receive notifications for issues

**Acceptance Criteria**:
- [ ] Alertmanager deployed (part of kube-prometheus)
- [ ] Alert routes configured
- [ ] Silence/inhibit rules working
- [ ] Web UI accessible

**Technical Notes**:
- Configure ntfy and Telegram receivers
- Group alerts to reduce noise

---

#### Story 2.4.6: Deploy ntfy
**As a** developer administrator  
**I want** ntfy deployed for push notifications  
**So that** I receive mobile alerts for critical issues

**Acceptance Criteria**:
- [ ] ntfy deployed on PROD cluster
- [ ] Topic created for homelab alerts
- [ ] Alertmanager webhook configured
- [ ] Mobile app receiving notifications
- [ ] Test alert received

**Technical Notes**:
- Self-hosted push notification service
- Free, no external dependencies

---

#### Story 2.4.7: Configure Alert Rules
**As a** developer administrator  
**I want** alert rules defined for critical events  
**So that** I'm notified of problems immediately

**Acceptance Criteria**:
- [ ] Disk space alerts (>80%, >90%)
- [ ] Service down alerts
- [ ] Node not ready alerts
- [ ] High CPU/memory alerts
- [ ] Backup failure alerts
- [ ] Security alerts (failed logins)

**Technical Notes**:
- PrometheusRule resources
- Prioritize by severity

---

### Epic 2.5: AdGuard Home DNS
**Priority**: P0 (Critical)  
**FR Reference**: FR-016  
**Description**: Deploy AdGuard Home for network-wide DNS and ad blocking.

#### Story 2.5.1: Deploy AdGuard Home
**As a** developer administrator  
**I want** AdGuard Home deployed on PROD cluster  
**So that** the home network has ad blocking and DNS filtering

**Acceptance Criteria**:
- [ ] AdGuard Home deployed via ArgoCD
- [ ] DNS service exposed (UDP 53)
- [ ] Web UI accessible for configuration
- [ ] DoH/DoT endpoints configured
- [ ] Ad blocking lists active

**Technical Notes**:
- Use MetalLB LoadBalancer for DNS
- Configure router to use AdGuard as DNS

---

---

## Phase 3: PROD Cluster + Oracle Cloud

### Epic 3.1: PROD Cluster Deployment
**Priority**: P0 (Critical)  
**FR Reference**: FR-002  
**Description**: Deploy the production Kubernetes cluster on Proxmox.

#### Story 3.1.1: Provision PROD VMs via Terraform
**As a** developer administrator  
**I want** PROD cluster VMs provisioned via Terraform  
**So that** the production infrastructure is reproducible

**Acceptance Criteria**:
- [ ] Control plane VM: 2 vCPU, 4GB RAM, 50GB
- [ ] Worker VM: 6 vCPU, 12GB RAM, 200GB
- [ ] VMs tagged: `talos`, `kubernetes`, `prod`
- [ ] Network configured on vmbr0

**Technical Notes**:
- Total: 8 vCPU, 16GB RAM
- Use Terraform modules from DEV

---

#### Story 3.1.2: Bootstrap PROD Cluster
**As a** developer administrator  
**I want** the PROD Kubernetes cluster bootstrapped  
**So that** I can run production workloads

**Acceptance Criteria**:
- [ ] Talos configuration applied
- [ ] Control plane bootstrapped
- [ ] Worker joined to cluster
- [ ] Cluster registered with Omni
- [ ] ArgoCD deployed and managing apps

**Technical Notes**:
- Separate control plane and worker
- Register with Omni immediately

---

#### Story 3.1.3: Deploy Longhorn Storage
**As a** developer administrator  
**I want** Longhorn deployed on PROD  
**So that** I have replicated persistent storage

**Acceptance Criteria**:
- [ ] Longhorn deployed via ArgoCD (Wave 1)
- [ ] `longhorn` StorageClass created
- [ ] Replication factor configured
- [ ] Longhorn UI accessible
- [ ] PVCs provisioning successfully

**Technical Notes**:
- Distributed storage for resilience
- Monitor disk usage

---

### Epic 3.2: Oracle Cloud Kubernetes Cluster
**Priority**: P0 (Critical)  
**FR Reference**: FR-002, FR-003  
**Description**: Deploy Kubernetes cluster on Oracle Cloud for external services.

#### Story 3.2.1: Provision OCI Compute via Terraform
**As a** developer administrator  
**I want** Kubernetes nodes on Oracle Cloud  
**So that** I can run family-facing services externally

**Acceptance Criteria**:
- [ ] oci-node-1: 2 OCPU, 12GB RAM, 64GB (control plane + worker)
- [ ] oci-node-2: 1 OCPU, 6GB RAM, 75GB (worker)
- [ ] VCN and subnet configured
- [ ] Security lists configured
- [ ] Static public IP assigned

**Technical Notes**:
- ARM shapes: VM.Standard.A1.Flex
- Stay within Always Free limits

---

#### Story 3.2.2: Bootstrap CLOUD Cluster
**As a** developer administrator  
**I want** the Oracle Cloud Kubernetes cluster bootstrapped  
**So that** I can run external services

**Acceptance Criteria**:
- [ ] Talos installed on OCI nodes
- [ ] Cluster bootstrapped
- [ ] Cluster registered with Omni
- [ ] ArgoCD syncing from Git
- [ ] Cilium CNI operational

**Technical Notes**:
- Use Talos for consistency
- May need cloud-init for initial boot

---

### Epic 3.3: Identity & Access
**Priority**: P0 (Critical)  
**FR Reference**: FR-008  
**Description**: Deploy Keycloak SSO and configure 2-tier authentication.

#### Story 3.3.1: Deploy Keycloak
**As a** developer administrator  
**I want** Keycloak deployed on the management VM  
**So that** I have centralized identity management

**Acceptance Criteria**:
- [ ] Keycloak container running
- [ ] PostgreSQL database configured
- [ ] Admin console accessible
- [ ] Realm created for homelab
- [ ] Users created (developer, designer, family)

**Technical Notes**:
- Deploy via Docker Compose on oci-mgmt
- Integrate with Omni for cluster access

---

#### Story 3.3.2: Configure oauth2-proxy
**As a** developer administrator  
**I want** oauth2-proxy deployed  
**So that** Tier 1 services require SSO login

**Acceptance Criteria**:
- [ ] oauth2-proxy deployed on CLOUD cluster
- [ ] Keycloak OIDC configured
- [ ] Cookie and session management working
- [ ] Upstream services protected
- [ ] Login flow tested

**Technical Notes**:
- Single instance protecting multiple services
- Configure allowed groups/users

---

#### Story 3.3.3: Configure Keycloak Clients
**As a** developer administrator  
**I want** OIDC clients configured for each Tier 1 service  
**So that** SSO works across all private services

**Acceptance Criteria**:
- [ ] Client for Nextcloud
- [ ] Client for Vaultwarden
- [ ] Client for Immich (Phase 5)
- [ ] Client for n8n (Phase 5)
- [ ] Client for Grafana
- [ ] Client for ArgoCD

**Technical Notes**:
- Export realm config for GitOps
- Store client secrets in ESO

---

### Epic 3.4: Cloudflare Tunnel & Zero Trust
**Priority**: P0 (Critical)  
**FR Reference**: FR-007, FR-010  
**Description**: Configure Cloudflare Tunnel and Twingate for zero-trust access.

#### Story 3.4.1: Deploy Cloudflare Tunnel
**As a** developer administrator  
**I want** Cloudflare Tunnel configured  
**So that** services are accessible without open ports

**Acceptance Criteria**:
- [ ] cloudflared running on oci-mgmt
- [ ] Tunnel created in Cloudflare dashboard
- [ ] Routes configured for services
- [ ] DNS records managed by Cloudflare
- [ ] WAF/DDoS protection active

**Technical Notes**:
- Docker container on management VM
- Config in `docker/oci-mgmt/cloudflared/`

---

#### Story 3.4.2: Deploy Twingate Connector
**As a** developer administrator  
**I want** Twingate connector deployed  
**So that** Oracle Cloud can access homelab NFS

**Acceptance Criteria**:
- [ ] Twingate connector deployed on CLOUD cluster
- [ ] Connector registered with Twingate network
- [ ] NFS resource defined in Twingate
- [ ] Access tested from Oracle Cloud pods
- [ ] Family users can access via Twingate client

**Technical Notes**:
- Free tier: 5 users
- Per-resource access control

---

### Epic 3.5: CI/CD Pipeline
**Priority**: P0 (Critical)  
**FR Reference**: FR-022, FR-023  
**Description**: Configure GitHub Actions for CI/CD.

#### Story 3.5.1: Create CI Pipeline
**As a** developer administrator  
**I want** CI pipeline validating all changes  
**So that** errors are caught before deployment

**Acceptance Criteria**:
- [ ] `.github/workflows/ci.yml` created
- [ ] kubeval manifest validation
- [ ] yamllint YAML linting
- [ ] Trivy security scanning
- [ ] GitGuardian secret detection
- [ ] CI runs on PRs and pushes

**Technical Notes**:
- Use GitHub Actions
- Fast feedback loop

---

#### Story 3.5.2: Create DEV Deployment Workflow
**As a** developer administrator  
**I want** automatic deployment to DEV on push  
**So that** changes are tested immediately

**Acceptance Criteria**:
- [ ] `.github/workflows/deploy-dev.yml` created
- [ ] Triggers on push to main
- [ ] ArgoCD sync triggered
- [ ] Deployment status reported
- [ ] Notifications sent

**Technical Notes**:
- Use ArgoCD CLI or webhook
- May use GitHub OIDC for auth

---

#### Story 3.5.3: Create PROD Promotion Workflow
**As a** developer administrator  
**I want** controlled promotion to PROD  
**So that** only stable changes reach production

**Acceptance Criteria**:
- [ ] `.github/workflows/promote-prod.yml` created
- [ ] Manual trigger via workflow_dispatch
- [ ] Optional: scheduled promotion
- [ ] DEV stability check before promotion
- [ ] Deployment notifications

**Technical Notes**:
- Query Prometheus for DEV stability
- Require approval for manual trigger

---

---

## Phase 4: Services MVP

### Epic 4.1: Critical Services
**Priority**: P0 (Critical)  
**FR Reference**: FR-011, FR-012, FR-013  
**Description**: Deploy critical family services on Oracle Cloud.

#### Story 4.1.1: Deploy Nextcloud
**As a** family member  
**I want** Nextcloud available for file storage  
**So that** I can backup and share files

**Acceptance Criteria**:
- [ ] Nextcloud deployed on CLOUD cluster
- [ ] Keycloak SSO configured
- [ ] NFS storage mounted via Twingate
- [ ] Accessible via Cloudflare Tunnel
- [ ] Mobile apps tested
- [ ] Performance >10 MB/s for uploads

**Technical Notes**:
- PostgreSQL or SQLite database
- Redis for caching (optional)

---

#### Story 4.1.2: Deploy Vaultwarden
**As a** family member  
**I want** Vaultwarden for password management  
**So that** I can securely store and share passwords

**Acceptance Criteria**:
- [ ] Vaultwarden deployed on CLOUD cluster
- [ ] Keycloak SSO configured
- [ ] Admin panel accessible
- [ ] Browser extensions working
- [ ] Mobile apps working
- [ ] Family organization created

**Technical Notes**:
- Lightweight Bitwarden implementation
- Backup database regularly

---

#### Story 4.1.3: Deploy Baïkal
**As a** family member  
**I want** Baïkal for calendar and contact sync  
**So that** I can sync across all devices

**Acceptance Criteria**:
- [ ] Baïkal deployed on CLOUD cluster
- [ ] Keycloak SSO configured
- [ ] CalDAV working (calendars)
- [ ] CardDAV working (contacts)
- [ ] Mobile devices syncing
- [ ] Multiple calendars per user

**Technical Notes**:
- Lightweight CalDAV/CardDAV server
- SQLite database sufficient

---

### Epic 4.2: Media Services
**Priority**: P0 (Critical)  
**FR Reference**: FR-014, FR-015  
**Description**: Deploy media streaming services.

#### Story 4.2.1: Deploy Comet
**As a** family member  
**I want** Comet addon for Stremio  
**So that** I can stream content via Real-Debrid

**Acceptance Criteria**:
- [ ] Comet deployed on CLOUD cluster
- [ ] Static IP maintained (OCI public IP)
- [ ] Accessible from Stremio clients
- [ ] Real-Debrid integration working
- [ ] High availability (>99% uptime)
- [ ] Monitoring alerts configured

**Technical Notes**:
- CRITICAL: Real-Debrid requires consistent IP
- Monitor uptime closely

---

#### Story 4.2.2: Deploy Navidrome
**As a** family member  
**I want** Navidrome for music streaming  
**So that** I can listen to my music library anywhere

**Acceptance Criteria**:
- [ ] Navidrome deployed on CLOUD cluster
- [ ] App-native auth configured (Tier 2)
- [ ] Music library via NFS (Twingate)
- [ ] Subsonic API working
- [ ] Mobile apps configured
- [ ] Multiple user accounts with playlists

**Technical Notes**:
- Subsonic-compatible clients
- Personal playlists per user

---

#### Story 4.2.3: Deploy Lidarr
**As a** developer administrator  
**I want** Lidarr for music library management  
**So that** the music library is organized

**Acceptance Criteria**:
- [ ] Lidarr deployed on CLOUD cluster
- [ ] App-native auth configured
- [ ] Music storage via NFS
- [ ] Navidrome integration working
- [ ] Metadata management functional

**Technical Notes**:
- Runs alongside Navidrome
- Manages downloads and organization

---

### Epic 4.3: Home Services
**Priority**: P1 (High)  
**FR Reference**: FR-017, FR-018  
**Description**: Deploy home automation and media library services on PROD.

#### Story 4.3.1: Deploy Home Assistant
**As a** developer administrator  
**I want** Home Assistant for home automation  
**So that** I can control smart home devices

**Acceptance Criteria**:
- [ ] Home Assistant deployed on PROD cluster
- [ ] Local network access working
- [ ] Device discovery functional
- [ ] Automations configurable
- [ ] Mobile app connected
- [ ] Backup configured

**Technical Notes**:
- May need host network for discovery
- Consider USB passthrough for Zigbee/Z-Wave

---

#### Story 4.3.2: Deploy Audiobookshelf
**As a** family member  
**I want** Audiobookshelf for audiobook streaming  
**So that** I can listen to audiobooks

**Acceptance Criteria**:
- [ ] Audiobookshelf deployed on PROD cluster
- [ ] App-native auth configured
- [ ] Audiobook library via NFS
- [ ] Progress tracking working
- [ ] Mobile apps functional

**Technical Notes**:
- Moved from Cloud to Homelab
- Local access primarily

---

#### Story 4.3.3: Deploy Komga
**As a** family member  
**I want** Komga for comics/manga  
**So that** I can read my comic library

**Acceptance Criteria**:
- [ ] Komga deployed on PROD cluster
- [ ] App-native auth configured
- [ ] Library via NFS
- [ ] Reading progress tracked
- [ ] Web reader functional
- [ ] Mobile apps working

**Technical Notes**:
- Comics and manga server
- Supports various formats

---

#### Story 4.3.4: Deploy Romm
**As a** developer administrator  
**I want** Romm for ROM management  
**So that** I can organize my retro game collection

**Acceptance Criteria**:
- [ ] Romm deployed on PROD cluster
- [ ] App-native auth configured
- [ ] ROM library via NFS
- [ ] Metadata scraped
- [ ] Web UI functional

**Technical Notes**:
- ROM manager with metadata
- Integrates with emulators

---

### Epic 4.4: Dashboard
**Priority**: P1 (High)  
**FR Reference**: FR-019  
**Description**: Deploy family-friendly dashboard.

#### Story 4.4.1: Deploy Glance
**As a** family member  
**I want** Glance as a homepage  
**So that** I can easily find all services

**Acceptance Criteria**:
- [ ] Glance deployed on CLOUD cluster
- [ ] Links to all family services
- [ ] Weather widget configured
- [ ] Calendar integration (optional)
- [ ] Accessible via Cloudflare Tunnel
- [ ] No authentication required (behind Cloudflare)

**Technical Notes**:
- Simple, fast dashboard
- Configurable via YAML

---

### Epic 4.5: Backup Implementation
**Priority**: P0 (Critical)  
**FR Reference**: FR-024, FR-025  
**Description**: Implement 3-2-1 backup strategy.

#### Story 4.5.1: Deploy Velero
**As a** developer administrator  
**I want** Velero for Kubernetes backup  
**So that** I can backup and restore workloads

**Acceptance Criteria**:
- [ ] Velero deployed on all clusters
- [ ] Backup schedules configured
- [ ] Cloud storage target (OVH S3)
- [ ] Restoration tested
- [ ] Backup monitoring in place

**Technical Notes**:
- Backup PVs and resources
- Schedule daily backups

---

#### Story 4.5.2: Configure Volsync/Restic
**As a** developer administrator  
**I want** file-level backups to cloud storage  
**So that** critical data is backed up offsite

**Acceptance Criteria**:
- [ ] Volsync or Restic configured
- [ ] Critical data identified and backed up
- [ ] Encryption enabled (user-provided key)
- [ ] OVH Object Storage target configured
- [ ] Backup verification automated

**Technical Notes**:
- 3TB free OVH storage
- Deduplicate and compress

---

#### Story 4.5.3: Configure ZFS Snapshots
**As a** developer administrator  
**I want** ZFS snapshots for local backup  
**So that** I can quickly recover from mistakes

**Acceptance Criteria**:
- [ ] Automatic snapshot schedule (hourly/daily/weekly)
- [ ] Snapshot retention policy configured
- [ ] Snapshot listing and restore documented
- [ ] zfs-auto-snapshot or sanoid configured

**Technical Notes**:
- Local point-in-time recovery
- Fast restoration

---

---

## Phase 5: Optional Services

### Epic 5.1: Optional Services Deployment
**Priority**: P2/P3 (Medium/Low)  
**FR Reference**: FR-028, FR-029, FR-030, FR-031  
**Description**: Deploy additional services when infrastructure is stable.

#### Story 5.1.1: Deploy Immich
**As a** family member  
**I want** Immich for photo management  
**So that** I can backup and organize photos

**Acceptance Criteria**:
- [ ] Immich deployed on CLOUD cluster
- [ ] Keycloak SSO configured
- [ ] Photo storage via NFS
- [ ] Mobile apps uploading
- [ ] Face recognition working (optional)
- [ ] Albums and sharing functional

**Technical Notes**:
- 2GB RAM required
- PostgreSQL + Redis + ML components

---

#### Story 5.1.2: Deploy n8n
**As a** developer administrator  
**I want** n8n for workflow automation  
**So that** I can automate tasks between services

**Acceptance Criteria**:
- [ ] n8n deployed on CLOUD cluster
- [ ] Keycloak SSO configured
- [ ] Webhook endpoints working
- [ ] Integration with ntfy
- [ ] Sample workflows created

**Technical Notes**:
- Self-hosted Zapier alternative
- 400+ integrations

---

#### Story 5.1.3: Deploy Mealie
**As a** family member  
**I want** Mealie for recipe management  
**So that** I can organize and plan meals

**Acceptance Criteria**:
- [ ] Mealie deployed on CLOUD cluster
- [ ] App-native auth configured
- [ ] Recipe import working
- [ ] Meal planning functional
- [ ] Shopping lists working

**Technical Notes**:
- Recipe management and meal planning
- Web scraping for import

---

#### Story 5.1.4: Deploy Invidious
**As a** family member  
**I want** Invidious for privacy-focused YouTube  
**So that** I can watch YouTube without tracking

**Acceptance Criteria**:
- [ ] Invidious deployed on CLOUD cluster
- [ ] App-native auth configured
- [ ] Subscriptions working
- [ ] Playlists functional
- [ ] Performance acceptable

**Technical Notes**:
- YouTube frontend
- May need instance rotation

---

---

## Phase 6: Gaming & Advanced

### Epic 6.1: Windows Gaming VM
**Priority**: P2 (Medium)  
**FR Reference**: FR-026  
**Description**: Configure Windows gaming VM with GPU passthrough.

#### Story 6.1.1: Create Windows Gaming VM
**As a** developer administrator  
**I want** a Windows VM for gaming  
**So that** I can play PC games remotely

**Acceptance Criteria**:
- [ ] Windows 11 VM created
- [ ] 32GB RAM, 8 vCPU allocated
- [ ] GPU passthrough working
- [ ] 1TB storage for games
- [ ] Network configured for remote access

**Technical Notes**:
- Proxmox VM (not K8s initially)
- May use Terraform or manual

---

#### Story 6.1.2: Configure Remote Gaming
**As a** developer administrator  
**I want** remote gaming access  
**So that** I can play from any device

**Acceptance Criteria**:
- [ ] Parsec installed and configured
- [ ] Moonlight/Sunshine configured (alternative)
- [ ] Steam Remote Play tested
- [ ] Latency acceptable (<50ms)
- [ ] Controller input working

**Technical Notes**:
- Multiple options for flexibility
- Test from Mac, Steam Deck, TV

---

#### Story 6.1.3: Configure On-Demand Startup
**As a** developer administrator  
**I want** the gaming VM to start on demand  
**So that** it doesn't consume resources when not in use

**Acceptance Criteria**:
- [ ] VM starts via API/script
- [ ] Notification when ready
- [ ] Auto-shutdown after inactivity
- [ ] Resource monitoring in place

**Technical Notes**:
- VM OFF by default
- Proxmox API for control

---

### Epic 6.2: KubeVirt Integration (Future)
**Priority**: P3 (Low)  
**FR Reference**: FR-027  
**Description**: Enable on-demand gaming via KubeVirt.

#### Story 6.2.1: Deploy KubeVirt
**As a** developer administrator  
**I want** KubeVirt for VM management in Kubernetes  
**So that** I can manage VMs via K8s API

**Acceptance Criteria**:
- [ ] KubeVirt deployed on PROD cluster
- [ ] VM CRDs available
- [ ] Test VM running
- [ ] GPU passthrough via KubeVirt

**Technical Notes**:
- Future enhancement
- GeForce Now-style experience

---

#### Story 6.2.2: Create Gaming VM Templates
**As a** developer administrator  
**I want** VM templates for instant gaming sessions  
**So that** VMs start quickly

**Acceptance Criteria**:
- [ ] Windows template created
- [ ] Template includes base gaming software
- [ ] Instant startup possible
- [ ] Template updates managed

**Technical Notes**:
- Pre-configured templates
- Reduce startup time

---

#### Story 6.2.3: Create Gaming Web Interface
**As a** developer administrator  
**I want** a web interface to launch gaming sessions  
**So that** gaming is easily accessible

**Acceptance Criteria**:
- [ ] Web UI to list/launch VMs
- [ ] Start/stop controls
- [ ] Session status visible
- [ ] Connect instructions displayed

**Technical Notes**:
- Simple web app
- Integrate with KubeVirt API

---

---

## Story Mapping Summary

### By Priority

| Priority | Stories | Phases |
|----------|---------|--------|
| P0 (Critical) | 42 | 1, 2, 3, 4 |
| P1 (High) | 18 | 2, 3, 4 |
| P2 (Medium) | 7 | 5, 6 |
| P3 (Low) | 3 | 5, 6 |
| **Total** | **70** | |

### By Cluster

| Cluster | Stories | Phases |
|---------|---------|--------|
| DEV (Homelab) | 12 | 1, 2 |
| PROD (Homelab) | 20 | 3, 4, 6 |
| CLOUD (Oracle) | 18 | 3, 4, 5 |
| Management VM | 8 | 1, 3 |
| CI/CD (GitHub) | 3 | 3 |
| Cross-cutting | 9 | All |

### By User

| User | Stories |
|------|---------|
| Developer Administrator | 52 |
| Family Members | 18 |

---

## Dependencies Graph

```
Phase 1: Foundation
├── Epic 1.1: Proxmox Setup
│   └── Epic 1.2: DEV Cluster (depends on 1.1)
│       └── Epic 1.4: ArgoCD (depends on 1.2)
│           └── Epic 1.5: Cilium (depends on 1.4)
└── Epic 1.3: Omni Setup
    └── Registers DEV cluster

Phase 2: Core Infrastructure (depends on Phase 1)
├── Epic 2.1: Storage (depends on 1.4)
├── Epic 2.2: cert-manager (depends on 1.4)
├── Epic 2.3: ESO + external-dns (depends on 1.4)
├── Epic 2.4: Monitoring (depends on 2.1, 2.3)
└── Epic 2.5: AdGuard (depends on 2.4)

Phase 3: PROD + Oracle Cloud (depends on Phase 2)
├── Epic 3.1: PROD Cluster (depends on 1.1, 1.3)
├── Epic 3.2: CLOUD Cluster (depends on 1.3)
├── Epic 3.3: Identity (depends on 1.3.1)
├── Epic 3.4: Tunnel + Twingate (depends on 3.2)
└── Epic 3.5: CI/CD (depends on 3.1, 3.2)

Phase 4: Services MVP (depends on Phase 3)
├── Epic 4.1: Critical Services (depends on 3.3, 3.4)
├── Epic 4.2: Media Services (depends on 3.4)
├── Epic 4.3: Home Services (depends on 3.1)
├── Epic 4.4: Dashboard (depends on 4.1, 4.2)
└── Epic 4.5: Backup (depends on 3.1, 3.2)

Phase 5: Optional Services (depends on Phase 4)
└── Epic 5.1: Optional (depends on 4.1 stable)

Phase 6: Gaming (depends on Phase 3)
├── Epic 6.1: Gaming VM (depends on 1.1.3)
└── Epic 6.2: KubeVirt (depends on 3.1)
```

---

## Success Metrics

| Phase | Key Metric | Target |
|-------|------------|--------|
| 1 | DEV cluster operational | Kubernetes Ready |
| 2 | Monitoring active | Prometheus scraping |
| 3 | All clusters managed | 3 clusters in Omni |
| 4 | Family adoption | >20 days/month usage |
| 5 | Service stability | >95% uptime |
| 6 | Gaming functional | 60 FPS, <50ms latency |

---

## Document Approval

- **Status**: Draft
- **Next Steps**: Review and prioritize, then Implementation Readiness check
- **Total Epics**: 20
- **Total Stories**: 70

---

*End of Epics and Stories Document*
