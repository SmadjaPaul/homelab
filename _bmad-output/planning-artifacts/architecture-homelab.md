---
date: 2026-01-23
project: homelab
version: 2.1
status: current
lastUpdated: 2026-01-23
note: Updated to reflect current implementation state - Traefik IngressRoute patterns, deployed services (WireGuard, Traefik)
---

# Architecture Document: Homelab Infrastructure

**Purpose**: This document defines the final architectural decisions, implementation patterns, and project structure for the homelab infrastructure. It is optimized for AI dev agents implementing the system.

---

## 1. Project Context

### Requirements Summary

**Functional Requirements**: 29 FRs organized into:
- Infrastructure Foundation (FR-001 to FR-003): Proxmox VE, Talos Linux, ZFS storage, Kubernetes
- Core Services (FR-004 to FR-007): Nextcloud, Pi-hole, Immich, Jellyfin + arr* suite
- Gaming Virtualization (FR-008 to FR-009): Windows and Steam OS VMs with GPU passthrough
- Security Infrastructure (FR-010 to FR-015): Firewall, VPN, HTTPS reverse proxy, authentication, security updates, image scanning
- Backup & Disaster Recovery (FR-016 to FR-021): 3-2-1 strategy, selective critical backup, cloud integration, encryption
- Monitoring & Alerting (FR-022 to FR-024): Prometheus/Grafana, Alertmanager, mobile push notifications
- Hybrid Cloud Architecture (FR-025): Oracle Cloud VPS for Internet-exposed services
- User Management (FR-026 to FR-027): Account management, family access
- Infrastructure as Code (FR-028): All configurations in code
- IP KVM Access (FR-029): Remote server management

**Non-Functional Requirements**: 20 NFRs covering performance, reliability, security, maintainability, scalability, cost, and compatibility.

**Hardware**: AOOSTAR WTR MAX 8845 (64GB RAM, 1TB SSD, 2x 20TB HDD)

**Target Users**: Developer administrator (Paul), graphic designer (non-technical power user), family members (5 people)

---

## 2. Core Architectural Decisions

### 2.1 Hypervisor and Base OS

**Decision**: Proxmox VE (Hypervisor) → Talos Linux (Base OS) → Kubernetes standard

**Architecture Stack:**
```
Proxmox VE (Hypervisor)
├── VM "Kubernetes Cluster" (Talos Linux, 8-16GB RAM)
│   ├── Talos Control Plane Node (Kubernetes Master)
│   ├── Talos Worker Nodes (Kubernetes Workers, optional for HA)
│   ├── Flux GitOps Operator
│   ├── Services Kubernetes (Nextcloud, Jellyfin, etc.)
│   └── Monitoring Stack (Prometheus, Grafana)
├── VM "Windows Gaming" (Ubuntu/Windows, GPU passthrough, 16GB RAM)
├── VM "Steam OS Gaming" (Steam OS, GPU passthrough, 16GB RAM)
└── Storage ZFS (on Proxmox or dedicated VM)
```

**Rationale**:
- Proxmox: Web-based VM management, simplified GPU passthrough, Terraform support
- Talos Linux: Immutable OS optimized for Kubernetes, API-only management, minimal overhead
- Kubernetes standard: Included in Talos, no need for K3s (which would be redundant)
- GitOps native: Flux automatic synchronization from Git

**Trade-offs**:
- Hypervisor overhead (~2-4GB RAM) → Acceptable with 64GB total RAM
- Kubernetes overhead (~1-2GB RAM for control plane) → Acceptable
- Talos learning curve (API-only, no SSH) → Compensated by Kubernetes knowledge + AI assistance

---

### 2.2 Service Orchestration

**Decision**: Kubernetes + Flux GitOps

**Rationale**:
- GitOps native with Flux automatic synchronization
- Advanced auto-healing and resilience
- Service discovery and networking built-in
- Rolling updates without downtime
- Future extensibility guaranteed (no migration needed)

**Implementation**: Kubernetes manifests in `kubernetes/base/` with Flux GitOps operator for automatic synchronization

---

### 2.3 Networking Architecture

**Decision**: Cilium v1.18 (eBPF-based CNI)

**Rationale**:
- Performance: eBPF-based networking reduces packet latency by ~40%
- Observability: Built-in Hubble for real-time network visibility
- Security: Native support for Layer 7 network policies, built-in WireGuard encryption
- Modern Architecture: Replaces kube-proxy with eBPF

**Version**: Cilium v1.18

---

### 2.4 Storage Architecture

**Decision**: ZFS CSI Driver (Local Persistent Volumes)

**Rationale**:
- Native ZFS integration with existing ZFS storage on Proxmox
- Snapshot support for backup and recovery
- Data integrity with ZFS checksums
- Optimal performance (local storage)

**Implementation**: Deploy ZFS CSI Driver, configure StorageClass `zfs-storage` for PersistentVolumes

---

### 2.5 Certificate Management

**Decision**: cert-manager v1.19.2

**Rationale**:
- Industry standard for Kubernetes certificate management
- Automatic Let's Encrypt certificate provisioning and renewal
- Seamless integration with Traefik ingress controller
- Automatic certificate lifecycle management

**Version**: cert-manager v1.19.2

---

### 2.6 DNS Management

**Decision**: external-dns (Kubernetes-native DNS management)

**Rationale**:
- Automatic DNS record creation/update from Kubernetes resources
- Multi-provider support (Cloudflare, AWS Route53, etc.)
- GitOps integration (DNS changes tracked in Git)
- Maintenance reduction (no manual DNS configuration)

---

### 2.7 Security Architecture

**Secrets Management**: External Secrets Operator + (Bitwarden initial → Vault long-term)
- Phase 1: Bitwarden Secrets (simplicity)
- Phase 2: Migration to Vault (optimal long-term)
- Migration path documented

**Container Image Security**: Trivy scanning pre-deployment (CI/CD)
- Pre-deployment scanning blocks vulnerable images
- Automated scanning on image updates (Renovate)
- Critical vulnerabilities block deployment
- Runtime scanning (future enhancement)

**Security Layers**:
1. Image Scanning: Trivy in CI/CD
2. Secret Management: Vault/Bitwarden + External Secrets Operator
3. Network Security: WireGuard VPN
4. Access Control: Kubernetes RBAC + Network Policies
5. Immutable OS: Talos Linux (no SSH, API-only)
6. Secret Detection: GitGuardian

---

### 2.8 Hybrid Cloud Architecture

**Decision**: Hybrid architecture with WireGuard tunnel (public services on VPS, private data on homelab)

**Rationale**: Security (minimize home network exposure), cost efficiency (Oracle Cloud Always Free), performance (local data access)

**Implementation**: Traefik on VPS for reverse proxy, conditional routing based on service type

---

### 2.9 Storage & Backup Strategy

**Decision**: ZFS with 3-2-1 selective backup (declarative tagging system for critical data)

**Rationale**: Data integrity (ZFS), cost optimization (selective cloud backup), rapid recovery

**Implementation**: Declarative tagging config files, modular backup scripts per data type

---

### 2.10 Monitoring Stack

**Decision**: Prometheus/Grafana modular with push notification alerts

**Rationale**: Industry standard, modular service metrics, actionable alerts

**Implementation**: Lightweight exporters, Alertmanager with priority routing, Gotify/Ntfy integration

---

## 3. Implementation Patterns & Consistency Rules

**Purpose**: Define consistent implementation patterns that prevent AI agent conflicts and ensure all code works together seamlessly.

**Critical Principle**: All AI agents implementing services MUST follow these patterns exactly. Deviations will cause conflicts and break GitOps automation.

---

### Pattern Category 1: Kubernetes Resource Structure

**Mandatory Structure Pattern:**
```
kubernetes/base/[service-name]/
├── deployment.yaml          # REQUIRED: Deployment resource
├── service.yaml             # REQUIRED: Service resource
├── ingressroute.yaml        # REQUIRED if exposed: IngressRoute (Traefik) OR ingress.yaml (Kubernetes Ingress)
├── configmap.yaml           # OPTIONAL: ConfigMap (non-sensitive config)
├── external-secret.yaml     # REQUIRED if secrets: ExternalSecret resource
├── pvc.yaml                 # REQUIRED if storage needed: PersistentVolumeClaim
├── network-policy.yaml      # REQUIRED: NetworkPolicy for service isolation
├── servicemonitor.yaml     # REQUIRED if metrics: ServiceMonitor for Prometheus
└── README.md                # REQUIRED: Service documentation
```

**Note**: Use `ingressroute.yaml` for Traefik IngressRoute (recommended) or `ingress.yaml` for standard Kubernetes Ingress.

**Multi-Component Services Rule:**
- **One service = one directory**: Each service gets its own directory, even if part of a larger ecosystem
- **Example**: `arr-sonarr/` and `arr-radarr/` are separate services (separate directories)
- **Documentation**: If services are related (e.g., arr* stack), document the relationship in each service's README.md
- **Dependencies**: Use initContainers and NetworkPolicy to manage inter-service communication

**Rules:**
- ✅ All resources for a service MUST be in `kubernetes/base/[service-name]/`
- ✅ Service name MUST be kebab-case (e.g., `nextcloud`, `jellyfin`, `arr-sonarr`)
- ✅ One resource per file (no multiple resources in single YAML)
- ✅ Files MUST be named exactly as shown above
- ❌ NEVER create resources in root `kubernetes/base/` directory
- ❌ NEVER mix multiple services in one directory

---

### Pattern Category 2: Naming Conventions

**Resource Naming Pattern:**
- **Deployment**: `[service-name]` (e.g., `nextcloud`, `jellyfin`)
- **Service**: `[service-name]` (e.g., `nextcloud`, `jellyfin`)
- **ConfigMap**: `[service-name]-config` (e.g., `nextcloud-config`)
- **ExternalSecret**: `[service-name]-secrets` (e.g., `nextcloud-secrets`)
- **PVC**: `[service-name]-storage` (e.g., `nextcloud-storage`)
- **Ingress**: `[service-name]` (e.g., `nextcloud`)
- **NetworkPolicy**: `[service-name]-network-policy` (e.g., `nextcloud-network-policy`)
- **ServiceMonitor**: `[service-name]-monitor` (e.g., `nextcloud-monitor`)

**Label Pattern (MANDATORY for all resources):**
```yaml
labels:
  app: [service-name]           # REQUIRED: Service identifier
  managed-by: flux               # REQUIRED: GitOps indicator
  version: [version]             # OPTIONAL: Service version
```

**Annotation Pattern:**
```yaml
annotations:
  # Cert-manager (for Ingress)
  cert-manager.io/cluster-issuer: letsencrypt-prod
  
  # External DNS (for Ingress)
  external-dns.alpha.kubernetes.io/hostname: [service-name].[domain]
  external-dns.alpha.kubernetes.io/ttl: "300"
  
  # Custom annotations (prefixed)
  homelab.paul/backup: "true"    # If service data needs backup
  homelab.paul/critical: "true"  # If service is critical
```

**Rules:**
- ✅ All resources MUST include `app: [service-name]` and `managed-by: flux` labels
- ✅ Service names MUST be kebab-case (lowercase, hyphens only)
- ❌ NEVER use camelCase or snake_case for service names
- ❌ NEVER use uppercase in service names

---

### Pattern Category 3: Secrets Management

**Mandatory Pattern: ExternalSecret (NEVER use Secret directly)**

```yaml
# kubernetes/base/[service-name]/external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: [service-name]-secrets
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend          # or bitwarden-backend
    kind: SecretStore
  target:
    name: [service-name]-secrets
    creationPolicy: Owner
  data:
  - secretKey: [key-name]
    remoteRef:
      key: homelab/[service-name]
      property: [property-name]
```

**Vault Path Pattern:**
- Path format: `kv/homelab/[service-name]`
- Example: `kv/homelab/nextcloud` for Nextcloud secrets

**Usage in Deployment:**
```yaml
# In deployment.yaml
env:
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: [service-name]-secrets
      key: [key-name]
```

**Resilience Pattern:**
- **`creationPolicy: Owner`**: Ensures Kubernetes Secret exists even if ExternalSecret cannot connect to Vault (once Secret is created)
- **First Deployment**: If Vault is unavailable during first deployment, Secret will NOT be created. Verify Vault connection before deployment.
- **Subsequent Deployments**: Once Secret exists, service can run even if Vault is temporarily unavailable

**Rules:**
- ✅ ALWAYS use ExternalSecret, NEVER create Secret directly
- ✅ Secret name MUST be `[service-name]-secrets`
- ✅ Vault path MUST be `homelab/[service-name]`
- ✅ Use `creationPolicy: Owner` for resilience
- ✅ Verify Vault connectivity before first deployment
- ❌ NEVER hardcode secrets in ConfigMap or Deployment
- ❌ NEVER commit secrets to Git (even encrypted)

---

### Pattern Category 4: Storage Management

**Mandatory Pattern: ZFS CSI StorageClass**

```yaml
# kubernetes/base/[service-name]/pvc.yaml (if storage needed)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: [service-name]-storage
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: zfs-storage    # REQUIRED: Use ZFS StorageClass
  resources:
    requests:
      storage: [size]              # e.g., 100Gi
```

**Usage in Deployment:**
```yaml
# In deployment.yaml
volumeMounts:
- name: [service-name]-storage
  mountPath: /data
volumes:
- name: [service-name]-storage
  persistentVolumeClaim:
    claimName: [service-name]-storage
```

**Rules:**
- ✅ ALWAYS use `storageClassName: zfs-storage` for PersistentVolumes
- ✅ PVC name MUST be `[service-name]-storage`
- ✅ Use `ReadWriteOnce` access mode (ZFS local storage)
- ❌ NEVER create PersistentVolumes manually
- ❌ NEVER use default StorageClass

---

### Pattern Category 5: Networking & Security

**Mandatory Pattern: NetworkPolicy for every service**

```yaml
# kubernetes/base/[service-name]/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: [service-name]-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: [service-name]
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: default
    - podSelector:
        matchLabels:
          app: traefik              # Allow ingress from Traefik
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: [dependent-service]  # If service depends on another
    ports:
    - protocol: TCP
      port: [port]
  - to: []                          # Allow all egress (or restrict as needed)
```

**Special Networking Requirements:**

**Host Network Services** (e.g., WireGuard VPN):
- Services requiring direct host network access MUST use `hostNetwork: true`
- Example: WireGuard VPN needs host network to bind to host interface
- DNS policy: Use `dnsPolicy: ClusterFirstWithHostNet` when using hostNetwork
- NetworkPolicy: May need special consideration for hostNetwork services

```yaml
# Example: WireGuard VPN deployment
spec:
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  containers:
  - name: wireguard
    securityContext:
      capabilities:
        add:
          - NET_ADMIN
          - SYS_MODULE
```

**Rules:**
- ✅ EVERY service MUST have a NetworkPolicy
- ✅ NetworkPolicy name MUST be `[service-name]-network-policy`
- ✅ Allow ingress from Traefik for exposed services
- ✅ Document inter-service dependencies in NetworkPolicy
- ✅ Document special networking requirements (hostNetwork, etc.) in README.md
- ❌ NEVER deploy services without NetworkPolicy

---

### Pattern Category 6: Monitoring Integration

**Mandatory Pattern: ServiceMonitor for services with metrics**

```yaml
# kubernetes/base/[service-name]/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: [service-name]-monitor
  namespace: default
spec:
  selector:
    matchLabels:
      app: [service-name]
  endpoints:
  - port: metrics                  # REQUIRED: Service port MUST be named "metrics"
    interval: 30s
    path: /metrics
```

**Service Port Naming (REQUIRED):**
```yaml
# In service.yaml, metrics port MUST be named
ports:
- name: metrics                    # REQUIRED: Must be named "metrics"
  port: 9090
  targetPort: 9090
```

**Rules:**
- ✅ ServiceMonitor REQUIRED if service exposes metrics
- ✅ ServiceMonitor name MUST be `[service-name]-monitor`
- ✅ Metrics port in Service MUST be named `metrics`
- ✅ Metrics endpoint path MUST be `/metrics`
- ❌ NEVER use different port names or paths

---

### Pattern Category 7: Ingress & TLS Certificates

**Mandatory Pattern: Traefik IngressRoute (PREFERRED) or Kubernetes Ingress**

**Option 1: Traefik IngressRoute (RECOMMENDED for advanced features)**

```yaml
# kubernetes/base/[service-name]/ingressroute.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: [service-name]
  namespace: default
  annotations:
    external-dns.alpha.kubernetes.io/hostname: [service-name].[domain]
    external-dns.alpha.kubernetes.io/ttl: "300"
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`[service-name].[domain]`)
      kind: Rule
      services:
        - name: [service-name]
          port: 80
      middlewares:
        - name: https-redirect
          namespace: traefik-system
  tls:
    certResolver: letsencrypt
    options:
      name: secure
      namespace: traefik-system
```

**Option 2: Kubernetes Ingress (for simple services)**

```yaml
# kubernetes/base/[service-name]/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: [service-name]
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    external-dns.alpha.kubernetes.io/hostname: [service-name].[domain]
    external-dns.alpha.kubernetes.io/ttl: "300"
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - [service-name].[domain]
    secretName: [service-name]-tls
  rules:
  - host: [service-name].[domain]
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: [service-name]
            port:
              number: 80
```

**Traefik Configuration Notes:**
- **TLS Options**: Use `secure` TLS options for production (A+ SSL rating)
- **HTTP Redirect**: Automatic redirect configured at Traefik entrypoint level
- **Cert Resolver**: Traefik uses `letsencrypt` cert resolver (not cert-manager annotations)
- **Middleware**: Use Traefik middleware for authentication, rate limiting, etc.

**Rules:**
- ✅ IngressRoute or Ingress REQUIRED for exposed services
- ✅ PREFER IngressRoute for advanced features (middleware, advanced routing)
- ✅ MUST use Traefik as ingress controller
- ✅ MUST include external-dns annotations for DNS automation
- ✅ MUST use `secure` TLS options for production services
- ✅ MUST use `letsencrypt` cert resolver (Traefik) or cert-manager (Ingress)
- ❌ NEVER use different ingress controllers
- ❌ NEVER manually create TLS certificates

---

### Pattern Category 8: Health Checks

**Mandatory Pattern: Liveness and Readiness Probes**

```yaml
# In deployment.yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

**Standard Timing:**
- **Liveness**: `initialDelaySeconds: 30`, `periodSeconds: 10`
- **Readiness**: `initialDelaySeconds: 10`, `periodSeconds: 5`
- **For slow services** (databases, etc.): Increase `initialDelaySeconds` to 60s for liveness, 30s for readiness

**Rules:**
- ✅ ALL deployments MUST have liveness and readiness probes
- ✅ Use standard timing unless service is slow (document reason)
- ✅ Document custom timing in service README.md
- ❌ NEVER deploy without health checks

---

### Pattern Category 9: Configuration Management

**Pattern: ConfigMap for non-sensitive configuration**

```yaml
# kubernetes/base/[service-name]/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: [service-name]-config
  namespace: default
data:
  config.yaml: |
    # Configuration content
```

**Usage in Deployment:**
```yaml
# In deployment.yaml
envFrom:
- configMapRef:
    name: [service-name]-config
# OR
volumeMounts:
- name: config
  mountPath: /etc/config
volumes:
- name: config
  configMap:
    name: [service-name]-config
```

**Rules:**
- ✅ Use ConfigMap for non-sensitive configuration
- ✅ ConfigMap name MUST be `[service-name]-config`
- ✅ NEVER put secrets in ConfigMap (use ExternalSecret)
- ❌ NEVER hardcode configuration in Deployment

---

### Pattern Category 10: Resource Limits & Requests

**Mandatory Pattern: Resource limits and requests**

```yaml
# In deployment.yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

**Resource Tiers:**
- **Small**: 256Mi memory, 100m CPU (requests) / 512Mi memory, 500m CPU (limits)
- **Medium**: 512Mi memory, 250m CPU (requests) / 1Gi memory, 1000m CPU (limits)
- **Large**: 1Gi memory, 500m CPU (requests) / 2Gi memory, 2000m CPU (limits)

**Rules:**
- ✅ ALL containers MUST have resource requests and limits
- ✅ Use Medium tier by default if uncertain
- ✅ Document resource requirements in service README.md
- ❌ NEVER deploy without resource limits

---

### Pattern Category 11: Image Security

**Mandatory Pattern: Image scanning and versioning**

```yaml
# In deployment.yaml
spec:
  containers:
  - name: [service-name]
    image: [registry]/[image]:[tag]  # Use specific tags, never :latest
    imagePullPolicy: IfNotPresent
```

**Rules:**
- ✅ NEVER use `:latest` tag (use specific versions)
- ✅ Images MUST be scanned by Trivy before deployment (CI/CD)
- ✅ Critical vulnerabilities MUST block deployment
- ✅ Document image source and version in service README.md
- ❌ NEVER deploy unscanned images

---

### Pattern Category 12: Dependencies & Init Containers

**Pattern: Init containers for service dependencies**

```yaml
# In deployment.yaml
initContainers:
- name: wait-for-database
  image: busybox:1.36
  command:
  - sh
  - -c
  - |
    until nc -z database-service 5432; do
      echo "Waiting for database..."
      sleep 2
    done
```

**Rules:**
- ✅ Use initContainers for service dependencies
- ✅ Document dependencies in service README.md
- ✅ Use NetworkPolicy to allow dependency communication
- ❌ NEVER assume dependencies are ready

---

### Pattern Category 13: GitOps Integration

**Mandatory Pattern: Flux Kustomization**

```yaml
# flux/apps/[service-name].yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: [service-name]
  namespace: flux-system
spec:
  interval: 10m
  path: ./kubernetes/base/[service-name]
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
```

**Rules:**
- ✅ Every service MUST have a Flux Kustomization
- ✅ Kustomization name MUST match service name
- ✅ Path MUST be `./kubernetes/base/[service-name]`
- ✅ Enable `prune: true` for automatic cleanup
- ❌ NEVER deploy services manually (always via GitOps)

---

### Pattern Category 14: Validation & Testing Patterns

**Validation Checklist (for each service):**
- [ ] All required files present (deployment.yaml, service.yaml, etc.)
- [ ] Naming conventions followed (kebab-case, correct prefixes)
- [ ] Labels include `app: [service-name]` and `managed-by: flux`
- [ ] ExternalSecret used (not Secret) if secrets needed
- [ ] NetworkPolicy present and configured
- [ ] ServiceMonitor present if metrics exposed
- [ ] IngressRoute or Ingress configured with TLS if exposed
- [ ] Health checks (liveness and readiness) configured
- [ ] Resource limits and requests set
- [ ] Image uses specific tag (not :latest)
- [ ] PVC present if storage needed
- [ ] README.md documents service, dependencies, and configuration

**Validation Script:**
```bash
# scripts/validate-service.sh [service-name]
# Validates service against all pattern requirements
# Returns exit code 0 if compliant, 1 if violations found
```

**Pre-commit Hook:**
```bash
# .git/hooks/pre-commit
# Run validation script for changed services
# Block commit if pattern violations found
```

**Rules:**
- ✅ Validate against checklist before committing
- ✅ Use validation script for automated checks
- ❌ NEVER deviate from patterns without discussion
- ❌ NEVER create resources manually (always via Git + Flux)

---

## 4. Project Structure & Boundaries

### Complete Project Structure

```
homelab/
├── .github/
│   └── workflows/                      # CI/CD automation
│       ├── kubernetes-sync.yml        # Flux GitOps sync (automatic)
│       ├── terraform.yml              # Auto-deploy infrastructure changes
│       ├── talos-update.yml           # Talos OS updates
│       ├── ansible.yml                # Auto-run Ansible playbooks
│       ├── renovate.yml               # Dependency update automation
│       └── trivy-scan.yml             # Security image scanning
│
├── .renovate/                          # Automated dependency updates
│   └── config.json                     # Renovate configuration
│
├── talos/                              # Talos Linux OS configuration
│   ├── controlplane.yaml              # Control plane node configuration
│   ├── worker.yaml                    # Worker nodes configuration
│   └── patches/                       # Talos system extensions
│
├── kubernetes/                         # Kubernetes manifests (primary)
│   ├── base/                           # Base Kubernetes manifests
│   │   ├── [service-name]/             # Per-service directory
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── ingress.yaml
│   │   │   ├── configmap.yaml
│   │   │   ├── external-secret.yaml
│   │   │   ├── pvc.yaml
│   │   │   ├── network-policy.yaml
│   │   │   ├── servicemonitor.yaml
│   │   │   └── README.md
│   └── overlays/                       # Environment-specific overlays
│       └── production/
│
├── flux/                               # GitOps operator (automatic sync)
│   ├── clusters/
│   │   └── homelab/                    # Kubernetes cluster on Talos
│   │       ├── flux-system/            # Flux bootstrap
│   │       └── cluster-config.yaml    # Cluster configuration
│   └── apps/                           # Application definitions
│       └── [service-name].yaml        # Flux Kustomization per service
│
├── terraform/                          # Infrastructure as Code
│   ├── proxmox/
│   │   ├── main.tf                     # Proxmox provider config
│   │   ├── talos-vms.tf               # Talos VM definitions
│   │   ├── gaming-vms.tf               # Gaming VMs (Windows/Steam OS)
│   │   └── [other resources].tf
│   └── cloud/
│       └── oracle-cloud/               # Oracle Cloud VPS resources
│
├── ansible/                            # Configuration management
│   ├── playbooks/
│   │   ├── zfs-setup.yml               # ZFS pool configuration
│   │   └── security-hardening.yml     # Security configuration
│   └── inventory/
│
├── storage/                            # Storage configurations
│   ├── zfs/
│   │   ├── pool-config.sh              # ZFS pool configuration
│   │   └── snapshot-policy.sh         # Snapshot automation
│   └── backup/
│       ├── backup-config.yml           # Backup configuration
│       └── tagging-rules.yml           # Critical data tagging rules
│
└── scripts/                             # Utility scripts
    ├── service-add.sh                  # Automated service addition
    ├── health-checks.sh                # Global health check script
    └── validate-service.sh             # Service validation script
```

### Requirements to Component Mapping

**Infrastructure Foundation (FR-001 to FR-003)**:
- FR-001 (Base OS): `talos/` - Talos Linux configuration
- FR-002 (Storage): `storage/zfs/` - ZFS pool configuration, `kubernetes/base/*/pvc.yaml` - PersistentVolumes
- FR-003 (Orchestration): `kubernetes/base/` - All service manifests, `flux/` - GitOps configuration

**Core Services (FR-004 to FR-007)**:
- All services: `kubernetes/base/[service-name]/` with standard structure

**Gaming Virtualization (FR-008 to FR-009)**:
- VM Definitions: `terraform/proxmox/gaming-vms.tf`

**Security Infrastructure (FR-010 to FR-015)**:
- Security Services: `kubernetes/base/security/[service-name]/`
- Security Configuration: `ansible/playbooks/security-hardening.yml`
- Scanning: `.github/workflows/trivy-scan.yml`

**Backup & Disaster Recovery (FR-016 to FR-021)**:
- Backup Configuration: `storage/backup/backup-config.yml`
- Tagging Rules: `storage/backup/tagging-rules.yml`

**Monitoring & Alerting (FR-022 to FR-024)**:
- Monitoring Stack: `kubernetes/base/monitoring/[component]/`
- ServiceMonitors: `kubernetes/base/[service-name]/servicemonitor.yaml`

**Hybrid Cloud Architecture (FR-025)**:
- VPS Infrastructure: `terraform/cloud/oracle-cloud/`
- VPN Configuration: `kubernetes/base/security/wireguard/`

### Integration Boundaries

**API Boundaries**:
- **Traefik Ingress**: Single entry point for all external traffic
- **Service Ingress**: Service-specific ingress rules
- **TLS Termination**: cert-manager (automatic via annotations)

**Component Boundaries**:
- **Infrastructure Layer**: Proxmox VMs, Talos OS, Storage
- **Orchestration Layer**: Kubernetes, GitOps, CI/CD
- **Service Layer**: Application services, Monitoring, Security
- **Configuration Layer**: Ansible, Terraform, Packer

**Data Boundaries**:
- **ZFS Local Storage**: Local storage configuration
- **Kubernetes PersistentVolumes**: Service storage
- **Backup Storage**: Backup configuration and cloud integration

---

## 5. Key Risks & Mitigations

### Critical Risks

**Hardware Failure**:
- Mitigation: 3-2-1 backup strategy, hardware monitoring, IP KVM for remote management

**Data Loss**:
- Mitigation: Automated backups, backup verification, encryption, rapid restoration procedures

**Security Compromise**:
- Mitigation: Automated security updates, firewall, VPN, security scanning, monitoring

**Service Unavailability**:
- Mitigation: Monitoring, alerting, auto-healing, capacity planning

**Infrastructure Complexity**:
- Mitigation: IaC approach, documentation, modular architecture, complexity tracking

---

## 6. Technology Stack Summary

**Infrastructure**:
- **Hypervisor**: Proxmox VE
- **OS**: Talos Linux (immutable, API-only)
- **Orchestration**: Kubernetes standard (included in Talos)
- **CNI**: Cilium v1.18 (eBPF-based)
- **CSI**: ZFS CSI Driver (Local PersistentVolumes)
- **GitOps**: Flux (automatic synchronization)
- **Certificate Management**: cert-manager v1.19.2
- **DNS Management**: external-dns
- **Secrets Management**: External Secrets Operator + HashiCorp Vault (self-hosted on Oracle VPS)
- **Image Scanning**: Trivy (in CI/CD)
- **Monitoring**: Prometheus + Grafana + Alertmanager
- **Ingress**: Traefik with cert-manager

**IaC Tools**:
- **Terraform**: VM provisioning (Proxmox, Oracle Cloud)
- **Ansible**: Configuration management (ZFS, security hardening)
- **Packer**: VM template builds

---

## 7. Current Implementation Status

**✅ Deployed Services**:
- **WireGuard VPN**: Deployed in `kubernetes/base/wireguard-vpn/` with hostNetwork enabled
- **Traefik**: Deployed in `kubernetes/base/traefik/` with IngressRoute CRDs, TLS, and middleware

**✅ Infrastructure Patterns Validated**:
- Kubernetes resource structure pattern confirmed
- Traefik IngressRoute pattern in use (not standard Ingress)
- NetworkPolicy pattern implemented
- PVC pattern implemented with ZFS storage class
- GitOps workflow functional (Flux syncing from Git)

**🔄 In Progress**:
- Additional services being deployed following established patterns
- Monitoring stack (Prometheus, Grafana) pending
- Core services (Nextcloud, etc.) pending

---

## 8. Implementation Readiness

**✅ Architecture Complete**:
- All architectural decisions documented
- Implementation patterns defined (14 categories)
- Project structure defined
- Requirements mapped to components
- Current implementation state documented

**✅ Dev Agent Ready**:
- Patterns prevent conflicts
- Structure is unambiguous
- Examples provided for clarity
- Validation checklist available
- Real-world examples from deployed services

**✅ Next Steps**:
1. Continue deploying services following established patterns
2. Deploy monitoring stack (Prometheus, Grafana, Alertmanager)
3. Deploy core services (Nextcloud, Pi-hole, etc.)
4. Configure secrets management (External Secrets Operator + Vault)
5. Set up backup infrastructure
6. Deploy additional services as per epics

---

**Document Status**: ✅ **CURRENT AND READY FOR IMPLEMENTATION**

All architectural decisions are final, patterns are defined, and structure is complete. Current implementation validates patterns. Dev agents should follow this document exactly when implementing services.
