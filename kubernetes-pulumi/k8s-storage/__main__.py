"""Homelab K8s Storage Stack.

This stack provides storage infrastructure:
- CSI Drivers (SMB, Local-Path)
- Databases (CNPG - PostgreSQL)
- Cache (Redis)

Stack Dependencies:
- k8s-core: Uses namespaces from core stack

Stack Outputs (exported for other stacks):
- storage_classes: available storage classes
- database_endpoints: CNPG cluster endpoints
- redis_endpoints: Redis endpoints
"""

import os

import pulumi
import pulumi_kubernetes as k8s
from shared.apps.loader import AppLoader
from shared.storage.s3_manager import S3Manager
from shared.utils.cluster import get_kubeconfig, create_provider
from shared.utils.schemas import HomelabStackConfig
from shared.apps.common.storagebox_orchestrator import StorageBoxOrchestrator


# Get project root
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
apps_yaml_path = os.path.join(project_root, "apps.yaml")

# =============================================================================
# STACK REFERENCES - Import from k8s-core
# =============================================================================
core_stack = pulumi.StackReference(
    f"organization/homelab-k8s-core/{pulumi.get_stack()}"
)
core_namespaces = core_stack.get_output("namespaces")
core_namespace_list = core_stack.get_output("namespace_list")
core_domain = core_stack.get_output("domain")
core_operator_status = core_stack.get_output("operator_status")

config = pulumi.Config()
cluster_filter = config.get("cluster") or "oci"

kubeconfig = get_kubeconfig()
provider = create_provider(cluster_filter, kubeconfig)

# Load apps configuration
loader = AppLoader(apps_yaml_path)
apps = loader.load_for_cluster(cluster_filter)
apps_by_name = {app.name: app for app in apps}

print(f"Stack: k8s-storage (cluster: {cluster_filter})")
core_namespace_list.apply(
    lambda ns: print(f"  Importing from k8s-core: namespaces = {ns}")
)

# =============================================================================
# STORAGE CLASSES
# =============================================================================
print("\nPhase 1: Setting up Storage Classes...")

# Load storagebox configuration from apps.yaml
raw_config = loader.get_full_config()
storage_box_id = raw_config.get("hcloud_storage_box_id", 537179)
storage_box_hostname = raw_config.get(
    "hcloud_storage_box_hostname", "u554589.your-storagebox.de"
)
storagebox_config = loader.load_storagebox_config()

if storagebox_config:
    StorageBoxOrchestrator(
        "storagebox",
        hostname=storage_box_hostname,
        storage_box_id=storage_box_id,
        config=storagebox_config,
        provider=provider,
    )

# Garder une StorageClass vide pour la compatibilité du driver
k8s.storage.v1.StorageClass(
    "hetzner-smb-sc",
    metadata={"name": "hetzner-smb"},
    provisioner="smb.csi.k8s.io",
    reclaim_policy="Retain",
    volume_binding_mode="Immediate",
    parameters={},  # Pas de source globale — chaque PV définit sa propre source
    opts=pulumi.ResourceOptions(provider=provider),
)


# Explicitly define oci-bv StorageClass for OKE Block Volumes
# This resolves the 'Pending' status for PVCs using oci-bv
k8s.storage.v1.StorageClass(
    "oci-bv-sc",
    metadata={
        "name": "oci-bv",
        "annotations": {"storageclass.kubernetes.io/is-default-class": "false"},
    },
    provisioner="blockvolume.csi.oraclecloud.com",
    reclaim_policy="Delete",
    volume_binding_mode="WaitForFirstConsumer",
    allow_volume_expansion=True,
    opts=pulumi.ResourceOptions(provider=provider),
)


# Get domain for config
domain = core_domain

# CSI Driver SMB (requires external-secrets to be ready)
csi_driver_ready = core_operator_status.apply(
    lambda s: s.get("external-secrets") == "deployed"
)

# Local Path Provisioner (always available)
local_path_apps = apps_by_name.get("local-path-provisioner")
if local_path_apps:
    print("  Deploying local-path-provisioner...")
    from shared.apps.generic import create_generic_app

    generic_app = create_generic_app(local_path_apps)
    result = generic_app.deploy(
        provider,
        config={"domain": domain},
        opts=pulumi.ResourceOptions(provider=provider),
    )

# CSI Driver SMB
csi_smb_apps = apps_by_name.get("csi-driver-smb")
if csi_smb_apps:
    print("  Deploying csi-driver-smb...")
    from shared.apps.generic import create_generic_app

    generic_app = create_generic_app(csi_smb_apps)
    result = generic_app.deploy(
        provider,
        config={"domain": domain},
        opts=pulumi.ResourceOptions(provider=provider),
    )

# =============================================================================
# DATABASES - CNPG
# =============================================================================
print("\nPhase 2: Setting up Databases (CNPG)...")

cnpg_apps = apps_by_name.get("cnpg-system")
if cnpg_apps:
    print("  Deploying CloudNativePG...")
    from shared.apps.generic import create_generic_app

    generic_app = create_generic_app(cnpg_apps)
    result = generic_app.deploy(
        provider,
        config={"domain": domain},
        opts=pulumi.ResourceOptions(provider=provider),
    )

# =============================================================================
# CACHE - Redis
# =============================================================================
print("\nPhase 3: Setting up Cache (Redis)...")

redis_apps = apps_by_name.get("redis")
if redis_apps:
    print("  Deploying Redis...")
    from shared.apps.generic import create_generic_app

    generic_app = create_generic_app(redis_apps)
    result = generic_app.deploy(
        provider,
        config={"domain": domain},
        opts=pulumi.ResourceOptions(provider=provider),
    )

# =============================================================================
# S3 / OBJECT STORAGE BUCKETS
# =============================================================================
print("\nPhase 4: Provisioning S3 Buckets...")

full_config = loader.get_full_config()
homelab_config = HomelabStackConfig(**full_config)

# Read OCI-specific config from Pulumi stack config (not from apps.yaml)
storage_config = pulumi.Config("homelab-k8s-storage")
oci_namespace = storage_config.get("ociNamespace") or "axnvxxurxefp"
oci_compartment_id = storage_config.get("ociCompartmentId")
cloudflare_account_id = storage_config.get("cloudflareAccountId")
stack_region = storage_config.get("ociRegion") or "eu-paris-1"

s3_manager = S3Manager(
    buckets=homelab_config.buckets,
    stack_region=stack_region,
    oci_namespace=oci_namespace,
    oci_compartment_id=oci_compartment_id,
    cloudflare_account_id=cloudflare_account_id,
)
s3_endpoints = s3_manager.provision_all()

# =============================================================================
# EXPORTS
# =============================================================================
pulumi.export(
    "storage_classes",
    {
        "local-path": "local-path-provisioner",
        "hetzner-smb": "csi-driver-smb",
    },
)

database_endpoints = {
    "cnpg-system": "cnpg-system.cnpg-system.svc.cluster.local:5432",
}
redis_endpoints = {
    "redis": "redis-master.storage.svc.cluster.local:6379",
}

pulumi.export("database_endpoints", database_endpoints)
pulumi.export("redis_endpoints", redis_endpoints)
pulumi.export("storage_provisioners", ["local-path", "hetzner-smb"])

# Export S3 endpoints so k8s-apps can consume them via StackReference
# Structure: { "db_backup_bucket": { endpoint_url, bucket_name, region, ... } }
pulumi.export("s3_endpoints", s3_endpoints)

print("\nStorage stack exports:")
print("  storage_classes: local-path, hetzner-smb")
print(f"  database_endpoints: {database_endpoints}")
print(f"  s3_buckets: {[b.name for b in homelab_config.buckets]}")
