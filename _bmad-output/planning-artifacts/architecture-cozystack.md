---
date: 2026-01-23
project: homelab
version: 1.0
status: greenfield
lastUpdated: 2026-01-23
note: Greenfield Cozystack implementation - comprehensive architecture document
---

# Architecture Document: Homelab Infrastructure with Cozystack

**Purpose**: This document defines the architectural decisions, implementation patterns, and project structure for a homelab infrastructure built on Cozystack - a Kubernetes-native platform for building private clouds.

---

## 1. Project Context

### Requirements Summary

**Functional Requirements**: Self-hosted homelab infrastructure providing:
- Infrastructure Foundation: Talos Linux, Kubernetes, Cozystack platform
- Core Services: Nextcloud, Pi-hole, Immich, Jellyfin + arr* suite
- Gaming Virtualization: Windows and Steam OS VMs with GPU passthrough
- Security Infrastructure: VPN, HTTPS reverse proxy, authentication
- Backup & Disaster Recovery: 3-2-1 strategy, selective critical backup, cloud integration
- Monitoring & Alerting: Prometheus/Grafana, Alertmanager, mobile push notifications
- Hybrid Cloud Architecture: Oracle Cloud VPS for Internet-exposed services
- User Management: Multi-tenant system with family access
- Infrastructure as Code: All configurations in code

**Hardware**: AOOSTAR WTR MAX 8845 (64GB RAM, 1TB SSD, 2x 20TB HDD)

**Target Users**: Developer administrator (Paul), graphic designer (non-technical power user), family members (5 people)

---

## 2. Core Architectural Decisions

### 2.1 Platform Choice: Cozystack

**Decision**: Cozystack - Kubernetes-native platform for building private clouds

**Architecture Stack:**
```
Bare Metal (AOOSTAR WTR MAX 8845)
├── Talos Linux (Immutable OS)
│   ├── Kubernetes Management Cluster
│   │   ├── Cozystack Platform
│   │   │   ├── KubeVirt (Virtualization)
│   │   │   ├── LINSTOR (Distributed Storage)
│   │   │   ├── Kube-OVN (Networking)
│   │   │   ├── Cilium (eBPF Networking)
│   │   │   ├── Flux CD (GitOps)
│   │   │   ├── GPU Operator (GPU Passthrough)
│   │   │   └── Managed Applications
│   │   ├── Tenant: root (System Services)
│   │   │   ├── Monitoring (Grafana, Victoria Metrics)
│   │   │   ├── Ingress (Nginx)
│   │   │   └── Etcd
│   │   ├── Tenant: services (Core Services)
│   │   │   ├── Nextcloud
│   │   │   ├── Pi-hole
│   │   │   ├── Immich
│   │   │   └── Jellyfin + arr* suite
│   │   └── Tenant: gaming (Gaming VMs)
│   │       ├── Windows Gaming VM (GPU passthrough)
│   │       └── Steam OS Gaming VM (GPU passthrough)
│   └── Storage: LINSTOR (DRBD + ZFS)
```

**Rationale**:
- **Unified Platform**: Everything runs in Kubernetes - containers, VMs, storage, networking
- **Cloud-Native**: Built for Kubernetes from the ground up
- **Multi-Tenant**: Built-in tenant system for isolation (family members, services, gaming)
- **Managed Services**: Pre-configured databases, queues, and services
- **GPU Passthrough**: Native support via GPU Operator (like NVIDIA GeForce Now)
- **Bare Metal**: No hypervisor overhead - Talos Linux directly on hardware
- **GitOps Native**: Flux CD built-in for Infrastructure as Code
- **CNCF Project**: Open source, actively developed, community-driven

**Trade-offs**:
- Learning curve: New platform to learn (but Kubernetes-native, so familiar concepts)
- Complexity: More moving parts than simple Proxmox setup
- Resource efficiency: Direct to Kubernetes, no hypervisor overhead
- Scalability: Designed for multi-node, but works on single node

---

### 2.2 Operating System: Talos Linux

**Decision**: Talos Linux - Immutable, API-only Linux distribution optimized for Kubernetes

**Rationale**:
- **Immutable**: System cannot be modified at runtime, ensuring consistency
- **API-Only**: No SSH, all management via API (more secure)
- **Kubernetes-Optimized**: Built specifically for running Kubernetes
- **Minimal Overhead**: ~200-300MB OS footprint
- **Atomic Updates**: System updates are atomic and rollback-capable
- **Cozystack Native**: Cozystack is designed to run on Talos Linux

**Installation Methods**:
- **Recommended**: `boot-to-talos` - Install from existing Linux OS
- **Alternative**: ISO image, PXE boot

---

### 2.3 Storage Architecture: LINSTOR (DRBD + ZFS)

**Decision**: LINSTOR for distributed block storage with ZFS backend

**Architecture**:
- **LINSTOR**: Management layer for DRBD volumes
- **DRBD**: Kernel-level replication (fastest block storage replication)
- **ZFS**: Underlying filesystem (data integrity, snapshots)
- **Storage Classes**:
  - `local`: Single-node storage (for non-critical workloads)
  - `replicated`: Multi-node replication (for critical data)

**Rationale**:
- **Hyperconverged**: Storage runs in Kubernetes (no external storage needed)
- **Replication**: DRBD provides fast replication across nodes
- **Data Integrity**: ZFS provides checksums and snapshots
- **Performance**: Kernel-level DRBD is faster than user-space solutions
- **Future-Proof**: Supports live migration of VMs

**Storage Pools**:
- **Primary Disk** (`/dev/sda`): Talos OS, etcd, system pods (1TB SSD)
- **Secondary Disk** (`/dev/sdb`): User data via LINSTOR (2x 20TB HDD in mirror)

---

### 2.4 Networking Architecture: Kube-OVN + Cilium

**Decision**: Kube-OVN for VM networking, Cilium for container networking

**Rationale**:
- **Kube-OVN**: Designed for virtual machines (VPCs, live migration, MAC management)
- **Cilium**: eBPF-based networking for containers (performance, observability)
- **Dual CNI**: Best of both worlds - VM-focused and container-focused networking
- **VPC Support**: Future capability for network isolation
- **MetalLB**: Load balancer for exposing services

**Network Configuration**:
- **Pod CIDR**: `10.244.0.0/16`
- **Service CIDR**: `10.96.0.0/16`
- **Join CIDR**: `100.64.0.0/16` (for tenant clusters)

---

### 2.5 Virtualization: KubeVirt

**Decision**: KubeVirt for running virtual machines in Kubernetes

**Rationale**:
- **Kubernetes-Native**: VMs managed as Kubernetes resources
- **GPU Passthrough**: Supported via GPU Operator
- **Live Migration**: Supported with replicated storage
- **Cloud-Native**: VMs treated like any other Kubernetes workload
- **Instance Types**: Pre-defined instance types (U, O, CX, M, RT series)

**Gaming VMs**:
- **Windows Gaming VM**: GPU passthrough via GPU Operator
- **Steam OS Gaming VM**: GPU passthrough via GPU Operator
- **Instance Type**: `cx1.xlarge` or `cx1.2xlarge` (dedicated CPU, hugepages)

---

### 2.6 GPU Passthrough: GPU Operator

**Decision**: NVIDIA GPU Operator for GPU passthrough to VMs

**Architecture**:
- **VFIO Manager**: Binds `vfio-pci` driver to GPUs
- **Sandbox Device Plugin**: Discovers and advertises GPUs to kubelet
- **Sandbox Validator**: Validates GPU configuration
- **KubeVirt Integration**: VMs request GPU resources via Kubernetes API

**Rationale**:
- **Native Support**: Built-in GPU passthrough support
- **Kubernetes-Native**: GPUs managed as Kubernetes resources
- **Similar to GeForce Now**: Same approach as NVIDIA's cloud gaming
- **Production-Ready**: Used in production environments

---

### 2.7 Multi-Tenancy: Cozystack Tenant System

**Decision**: Cozystack tenant system for isolation and organization

**Tenant Structure**:
- **root**: System services (monitoring, ingress, etcd)
- **services**: Core services (Nextcloud, Pi-hole, Immich, Jellyfin)
- **gaming**: Gaming VMs (Windows, Steam OS)
- **family**: Family member access (future)

**Rationale**:
- **Isolation**: Strict isolation between tenants
- **RBAC**: Role-based access control per tenant
- **Resource Management**: Quotas and limits per tenant
- **Scalability**: Easy to add new tenants

---

### 2.8 GitOps: Flux CD

**Decision**: Flux CD for GitOps automation

**Rationale**:
- **Built-in**: Cozystack uses Flux CD internally
- **Declarative**: All infrastructure defined in Git
- **Automatic Sync**: Changes automatically applied
- **Version Control**: Full history of infrastructure changes

---

## 3. Implementation Patterns & Consistency Rules

### Pattern Category 1: Cozystack Resource Structure

**Mandatory Structure Pattern:**
```
homelab/
├── cozystack/
│   ├── configmap.yaml          # Cozystack configuration
│   ├── storage-classes.yaml    # LINSTOR storage classes
│   └── metallb-config.yaml     # MetalLB configuration
├── tenants/
│   ├── root/
│   │   └── tenant.yaml         # Root tenant configuration
│   ├── services/
│   │   └── tenant.yaml         # Services tenant
│   └── gaming/
│       └── tenant.yaml         # Gaming tenant
├── applications/
│   ├── nextcloud/
│   │   └── virtualmachine.yaml # Nextcloud as VM or managed app
│   ├── gaming/
│   │   ├── windows-gaming.yaml # Windows gaming VM
│   │   └── steam-os-gaming.yaml # Steam OS gaming VM
│   └── monitoring/
│       └── monitoring.yaml     # Monitoring configuration
└── talos/
    ├── controlplane.yaml       # Control plane node config
    └── worker.yaml             # Worker node config
```

**Rules:**
- ✅ All Cozystack resources use Custom Resources (VirtualMachine, Tenant, etc.)
- ✅ Tenants organize services logically
- ✅ Use managed applications when available (PostgreSQL, Redis, etc.)
- ✅ Use VirtualMachine for custom workloads
- ❌ NEVER create resources directly in management cluster (use tenants)

---

### Pattern Category 2: Tenant Organization

**Tenant Naming Pattern:**
- **root**: System services only
- **services**: Core application services
- **gaming**: Gaming VMs
- **family-{name}**: Per-family-member tenants (future)

**Rules:**
- ✅ Each tenant has specific purpose
- ✅ Services isolated by tenant
- ✅ RBAC configured per tenant
- ✅ Resource quotas set per tenant

---

### Pattern Category 3: Storage Management

**Mandatory Pattern: LINSTOR Storage Classes**

```yaml
# Storage class for local storage (single node)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: linstor.csi.linbit.com
parameters:
  linstor.csi.linbit.com/storagePool: "data"
  linstor.csi.linbit.com/layerList: "storage"
  linstor.csi.linbit.com/allowRemoteVolumeAccess: "false"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
# Storage class for replicated storage
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: replicated
provisioner: linstor.csi.linbit.com
parameters:
  linstor.csi.linbit.com/storagePool: "data"
  linstor.csi.linbit.com/autoPlace: "3"
  linstor.csi.linbit.com/layerList: "drbd storage"
  linstor.csi.linbit.com/allowRemoteVolumeAccess: "true"
volumeBindingMode: Immediate
allowVolumeExpansion: true
```

**Rules:**
- ✅ Use `local` for non-critical, single-node workloads
- ✅ Use `replicated` for critical data (databases, VMs)
- ✅ Storage pools created via LINSTOR CLI
- ❌ NEVER use default Kubernetes storage classes

---

### Pattern Category 4: Virtual Machine Management

**Mandatory Pattern: VirtualMachine Custom Resource**

```yaml
apiVersion: apps.cozystack.io/v1alpha1
kind: VirtualMachine
metadata:
  name: windows-gaming
  namespace: tenant-gaming
spec:
  running: true
  instanceProfile: windows.11
  instanceType: cx1.2xlarge  # Dedicated CPU for gaming
  systemDisk:
    image: windows.11
    storage: 100Gi
    storageClass: replicated
  gpus:
  - name: nvidia.com/GA102GL_A10  # GPU resource name
  resources:
    cpu: "8"
    memory: "16Gi"
  cloudInit: |
    #cloud-config
    # Custom cloud-init configuration
```

**Instance Type Selection:**
- **Gaming VMs**: `cx1.xlarge` or `cx1.2xlarge` (dedicated CPU, hugepages)
- **Services**: `u1.medium` or `u1.large` (burstable CPU)
- **Databases**: `u1.large` or `u1.xlarge` (more memory)

**Rules:**
- ✅ Use appropriate instance types for workload
- ✅ Use `replicated` storage for VMs (enables live migration)
- ✅ Configure GPU passthrough via `gpus` field
- ✅ Use cloud-init for VM configuration
- ❌ NEVER use `local` storage for VMs (prevents migration)

---

### Pattern Category 5: GPU Passthrough Configuration

**Mandatory Pattern: GPU Operator Setup**

1. **Label node for GPU passthrough**:
```bash
kubectl label node <node-name> --overwrite nvidia.com/gpu.workload.config=vm-passthrough
```

2. **Enable GPU Operator bundle**:
```yaml
# In cozystack ConfigMap
bundle-enable: gpu-operator
```

3. **Configure KubeVirt for GPU passthrough**:
```yaml
# In KubeVirt Custom Resource
spec:
  configuration:
    permittedHostDevices:
      pciHostDevices:
      - externalResourceProvider: true
        pciVendorSelector: 10DE:2236  # NVIDIA GPU vendor:device
        resourceName: nvidia.com/GA102GL_A10
```

4. **Request GPU in VM**:
```yaml
spec:
  gpus:
  - name: nvidia.com/GA102GL_A10
```

**Rules:**
- ✅ Label nodes before enabling GPU Operator
- ✅ Verify GPU binding with `lspci -nnk -d 10de:`
- ✅ Check GPU resources with `kubectl describe node`
- ✅ Use correct resource name in VM spec

---

### Pattern Category 6: Networking Configuration

**MetalLB Configuration Pattern:**

```yaml
# IP Address Pool
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: cozystack
  namespace: cozy-metallb
spec:
  addresses:
    - 192.168.100.200-192.168.100.250
  autoAssign: true
---
# L2 Advertisement
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: cozystack
  namespace: cozy-metallb
spec:
  ipAddressPools:
    - cozystack
```

**Rules:**
- ✅ Use MetalLB for bare metal deployments
- ✅ Use public IPs for cloud provider deployments
- ✅ Configure appropriate IP ranges
- ✅ Enable ingress in root tenant

---

### Pattern Category 7: Managed Applications

**Pattern: Use Cozystack Managed Applications**

Cozystack provides managed applications:
- **Databases**: PostgreSQL, MySQL/MariaDB, Redis, ClickHouse, FerretDB
- **Queues**: Kafka, NATS, RabbitMQ
- **Storage**: SeaweedFS
- **Networking**: VPN, HTTP Cache, TCP Balancer
- **Kubernetes**: Tenant Kubernetes clusters

**Example: PostgreSQL**
```yaml
apiVersion: apps.cozystack.io/v1alpha1
kind: PostgreSQL
metadata:
  name: nextcloud-db
  namespace: tenant-services
spec:
  version: "17"
  storage: 50Gi
  storageClass: replicated
  users:
  - name: nextcloud
    password: <from-secret>
```

**Rules:**
- ✅ Use managed applications when available
- ✅ Prefer managed apps over custom deployments
- ✅ Configure storage classes appropriately
- ✅ Use secrets for sensitive data

---

## 4. Project Structure & Boundaries

### Complete Project Structure

```
homelab/
├── talos/                              # Talos Linux configuration
│   ├── controlplane.yaml              # Control plane node config
│   ├── worker.yaml                    # Worker node config
│   └── secrets.yaml                   # Cluster secrets (gitignored)
│
├── cozystack/                          # Cozystack configuration
│   ├── configmap.yaml                 # Cozystack ConfigMap
│   ├── storage-classes.yaml           # LINSTOR storage classes
│   ├── storage-pools.sh               # LINSTOR storage pool creation
│   └── metallb-config.yaml            # MetalLB configuration
│
├── tenants/                            # Tenant definitions
│   ├── root/
│   │   └── tenant.yaml                # Root tenant config
│   ├── services/
│   │   └── tenant.yaml                # Services tenant
│   └── gaming/
│       └── tenant.yaml                # Gaming tenant
│
├── applications/                       # Application definitions
│   ├── nextcloud/
│   │   ├── virtualmachine.yaml        # Nextcloud VM or managed app
│   │   └── README.md
│   ├── pi-hole/
│   │   ├── virtualmachine.yaml
│   │   └── README.md
│   ├── immich/
│   │   ├── virtualmachine.yaml
│   │   └── README.md
│   ├── jellyfin/
│   │   ├── virtualmachine.yaml
│   │   └── README.md
│   └── gaming/
│       ├── windows-gaming.yaml        # Windows gaming VM
│       ├── steam-os-gaming.yaml       # Steam OS gaming VM
│       └── README.md
│
├── monitoring/                         # Monitoring configuration
│   ├── dashboards/                    # Grafana dashboards
│   └── alerts/                        # Alert rules
│
├── networking/                         # Networking configuration
│   ├── vpn/                           # VPN configuration
│   └── ingress/                      # Ingress configuration
│
├── backup/                            # Backup configuration
│   ├── backup-config.yaml            # Backup strategy
│   └── tagging-rules.yaml           # Critical data tagging
│
├── scripts/                           # Utility scripts
│   ├── install-talos.sh              # Talos installation
│   ├── install-kubernetes.sh         # Kubernetes bootstrap
│   ├── install-cozystack.sh          # Cozystack installation
│   └── gpu-setup.sh                  # GPU passthrough setup
│
└── docs/                              # Documentation
    ├── installation.md                # Installation guide
    ├── configuration.md               # Configuration guide
    └── troubleshooting.md             # Troubleshooting guide
```

---

## 5. Technology Stack Summary

**Infrastructure**:
- **OS**: Talos Linux (immutable, API-only)
- **Orchestration**: Kubernetes standard (included in Talos)
- **Platform**: Cozystack (Kubernetes-native private cloud)
- **Virtualization**: KubeVirt
- **Storage**: LINSTOR (DRBD + ZFS)
- **Networking**: Kube-OVN + Cilium
- **Load Balancer**: MetalLB
- **GitOps**: Flux CD
- **GPU Passthrough**: NVIDIA GPU Operator
- **Monitoring**: Grafana + Victoria Metrics
- **Ingress**: Nginx Ingress Controller

**Managed Applications**:
- **Databases**: PostgreSQL, MySQL/MariaDB, Redis
- **Queues**: Kafka, NATS, RabbitMQ
- **Storage**: SeaweedFS
- **Networking**: VPN (Outline Server), HTTP Cache, TCP Balancer

---

## 6. Implementation Readiness

**✅ Architecture Complete**:
- All architectural decisions documented
- Implementation patterns defined (7 categories)
- Project structure defined
- Cozystack documentation reviewed

**✅ Key Advantages**:
- Unified Kubernetes platform (no hypervisor layer)
- Native GPU passthrough support
- Multi-tenant isolation
- Managed services included
- Cloud-native architecture

**✅ Next Steps**:
1. Install Talos Linux on bare metal
2. Bootstrap Kubernetes cluster
3. Install and configure Cozystack
4. Configure storage (LINSTOR)
5. Configure networking (MetalLB)
6. Set up tenants
7. Deploy applications
8. Configure GPU passthrough for gaming VMs

---

**Document Status**: ✅ **READY FOR IMPLEMENTATION**

All architectural decisions are final, patterns are defined, and structure is complete. This greenfield implementation will leverage Cozystack's full capabilities for a modern, cloud-native homelab.
