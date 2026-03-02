"""
Pydantic schemas for Homelab configuration.
Provides validation and IDE support for the Pulumi stack.
"""

from typing import List, Optional, Literal, Dict, Any, Union
from pydantic import BaseModel, Field, HttpUrl
from enum import Enum


class S3Provider(str, Enum):
    OCI = "oci"              # Oracle Cloud Object Storage (Always Free tier available)
    CLOUDFLARE = "cloudflare" # Cloudflare R2 (zero egress cost)
    GENERIC = "generic"      # Generic HTTP endpoint (self-hosted RustFS, MinIO, etc.)

class ExposureMode(str, Enum):
    PUBLIC = "public"
    PROTECTED = "protected"
    INTERNAL = "internal"

class StorageAccess(str, Enum):
    PRIVATE = "private"     # ReadWriteOnce, restricted to one pod/user (Block Volume)
    SHARED = "shared"       # ReadWriteMany, shared between pods/users (Hetzner Global)
    PRIVATE_SMB = "private-smb" # ReadWriteMany but using user-specific sub-account

class ResourceLimits(BaseModel):
    """CPU and Memory limits/requests."""
    cpu: str = Field("100m")
    memory: str = Field("128Mi")

class ResourceRequirements(BaseModel):
    """Standard Kubernetes resource requests and limits."""
    requests: ResourceLimits = Field(default_factory=ResourceLimits)
    limits: ResourceLimits = Field(default_factory=ResourceLimits)

class SecretRequirement(BaseModel):
    """Defines a secret requirement for an application."""
    name: str
    keys: Union[List[str], Dict[str, str]]
    remote_key: Optional[str] = None # If different from name

class StorageTier(str, Enum):
    EPHEMERAL = "ephemeral"   # Transient data, no backup
    PERSISTENT = "persistent" # Critical data, 3-2-1 eligible
    EXTERNAL = "external"     # NAS / S3 / External volumes

class StorageConfig(BaseModel):
    """Configuration for application storage and backups."""
    name: str = Field("data")
    tier: StorageTier = Field(StorageTier.PERSISTENT)
    access: StorageAccess = Field(StorageAccess.PRIVATE)
    size: str = Field("1Gi")
    mount_path: str = Field("/data")
    existing_claim: Optional[str] = None
    storage_class: Optional[str] = None
    backup_321: bool = Field(False, description="Flag for 3-2-1 backup strategy")
    external_source: Optional[str] = None # e.g. "s3://bucket-name" or "nfs://nas/path"

class AppCategory(str, Enum):
    PUBLIC = "public"
    PROTECTED = "protected"
    INTERNAL = "internal"
    DATABASE = "database"

class BackupDestination(BaseModel):
    """Configuration for S3-compatible database backups."""
    enabled: bool = False
    endpoint_url: Optional[str] = None
    bucket: Optional[str] = None
    access_key_id: Optional[str] = None      # Secret resource name
    secret_access_key: Optional[str] = None  # Secret resource name
    region: str = "us-east-1"
    schedule: str = "0 0 2 * * *" # Default 2 AM daily

class AppTier(str, Enum):
    CRITICAL = "critical"
    STANDARD = "standard"
    EPHEMERAL = "ephemeral"


class TestConfig(BaseModel):
    """Test configuration for an application."""
    test_routing: bool = True
    test_secrets: bool = True
    test_health: bool = True
    test_network_policy: bool = True
    expected_endpoints: List[str] = Field(default_factory=list)
    required_secrets: List[str] = Field(default_factory=list)
    excluded_secrets: List[str] = Field(default_factory=list)
    network_isolation: List[str] = Field(default_factory=list)


class HelmConfig(BaseModel):
    """Helm chart configuration."""
    chart: str
    repo: Optional[str] = None
    version: Optional[str] = None
    values: Dict[str, Any] = Field(default_factory=dict)


class DatabaseConfig(BaseModel):
    """Configuration for local database (CNPG)."""
    local: bool = False
    size: str = "1Gi"
    storage_class: Optional[str] = None

class AppModel(BaseModel):
    """Unified configuration for a single application."""
    name: str = Field(..., description="Internal name of the application")
    namespace: str = Field("default", description="Kubernetes namespace")
    port: int = Field(80, description="Service port")
    hostname: Optional[str] = Field(None, description="Exposed hostname")
    owner: Optional[str] = Field(None, description="Optional owner (user name) for private storage")
    mode: ExposureMode = Field(ExposureMode.INTERNAL)
    category: AppCategory = Field(AppCategory.INTERNAL)
    tier: AppTier = Field(AppTier.STANDARD)
    clusters: List[str] = Field(default_factory=lambda: ["oci", "local"])
    dependencies: List[str] = Field(default_factory=list)
    auth: bool = Field(True, description="Enable authentication proxy (Authentik)")
    auth_groups: List[str] = Field(default_factory=list)
    storage: List[StorageConfig] = Field(default_factory=list)
    database: Optional[DatabaseConfig] = None
    secrets: List[SecretRequirement] = Field(default_factory=list)
    values: Dict[str, Any] = Field(default_factory=dict, description="Custom Helm values (legacy/fallback)")
    values_file: Optional[str] = Field(None, description="Path to external values file")
    helm: Optional[HelmConfig] = None
    chart: Optional[str] = Field(None, description="Helm chart name (legacy, use helm.chart instead)")
    repo: Optional[str] = Field(None, description="Helm repository URL (legacy)")
    version: Optional[str] = Field(None, description="Helm chart version (legacy)")

    disable_auto_route: bool = Field(False, description="Disable automatic Route/Ingress generation")
    monitoring: bool = Field(True, description="Enable automatic ServiceMonitor generation")
    replicas: int = Field(1, description="Number of replicas (affects PDB generation)")
    resources: ResourceRequirements = Field(default_factory=ResourceRequirements)
    termination_grace_period: int = Field(30, description="Termination grace period in seconds")
    test: TestConfig = Field(default_factory=TestConfig)
    database_backup: BackupDestination = Field(default_factory=BackupDestination)

class IdentityGroupModel(BaseModel):
    """Configuration for an identity group."""
    name: str
    members: List[str] = Field(default_factory=list)
    is_superuser: bool = Field(False, description="Map to Authentik superuser permissions")

class IdentityUserModel(BaseModel):
    """Configuration for an identity user."""
    name: str
    display_name: Optional[str] = None
    email: Optional[str] = None
    groups: List[str] = Field(default_factory=list)
    attributes: Dict[str, Any] = Field(default_factory=dict, description="Custom Authentik attributes")

class IdentitiesModel(BaseModel):
    """Global identities configuration."""
    groups: List[IdentityGroupModel] = Field(default_factory=list)
    users: List[IdentityUserModel] = Field(default_factory=list)

class S3BucketConfig(BaseModel):
    """
    Defines an S3-compatible bucket to be managed by Pulumi.

    The 'provider' field selects which cloud backend will host this bucket.
    Credentials are always fetched from Doppler via the indicated secret keys.
    """
    name: str = Field(..., description="Bucket name")
    provider: S3Provider = Field(S3Provider.OCI, description="Storage provider backend")
    purpose: str = Field("general", description="Semantic use: 'backup', 'media', 'archive'...")
    tier: Literal["Standard", "InfrequentAccess", "Archive"] = Field(
        "Standard", description="Storage tier (providers map this to their own tiers)"
    )
    region: Optional[str] = Field(None, description="Override region for this bucket (default from stack config)")
    export_as: Optional[str] = Field(None, description="Stack output key to expose the endpoint URL")
    # Provider-specific credentials (Doppler key names)
    access_key_secret: str = Field("OCI_S3_ACCESS_KEY", description="Doppler key for S3 Access Key ID")
    secret_key_secret: str = Field("OCI_S3_SECRET_KEY", description="Doppler key for S3 Secret Key")
    # Endpoint override (for GENERIC provider or custom OCI namespace)
    endpoint_url: Optional[str] = Field(None, description="Override endpoint (required for provider=generic)")
    tags: Dict[str, str] = Field(default_factory=dict)
    protect: bool = Field(True, description="Prevent accidental bucket deletion (recommended for backups)")


class HomelabStackConfig(BaseModel):
    """Global configuration for the homelab stack."""
    domain: str = "smadja.dev"
    clusterName: str = "homelab"
    enableEnvoyGateway: bool = True
    enableMonitoring: bool = True
    enableLonghorn: bool = False
    renderYamlToDirectory: Optional[str] = Field(None, description="Native Pulumi YAML generation path")
    apps: List[AppModel] = Field(default_factory=list)
    identities: IdentitiesModel = Field(default_factory=list)
    buckets: List[S3BucketConfig] = Field(default_factory=list, description="S3-compatible buckets to provision")
