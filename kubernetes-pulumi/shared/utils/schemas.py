"""
Pydantic schemas for Homelab configuration.
Provides validation and IDE support for the Pulumi stack.
"""

from typing import List, Optional, Literal, Dict, Any, Union
from pydantic import BaseModel, Field, model_validator
from enum import Enum


class S3Provider(str, Enum):
    OCI = "oci"  # Oracle Cloud Object Storage (Always Free tier available)
    CLOUDFLARE = "cloudflare"  # Cloudflare R2 (zero egress cost)
    GENERIC = "generic"  # Generic HTTP endpoint (self-hosted RustFS, MinIO, etc.)


class ExposureMode(str, Enum):
    PUBLIC = "public"
    PROTECTED = "protected"
    INTERNAL = "internal"


class StorageAccess(str, Enum):
    PRIVATE = "private"  # ReadWriteOnce, restricted to one pod/user (Block Volume)
    SHARED = "shared"  # ReadWriteMany, shared between pods/users (Hetzner Global)
    PRIVATE_SMB = "private-smb"  # ReadWriteMany but using user-specific sub-account


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
    remote_key: Optional[str] = None  # If different from name


class ConfigMapRequirement(BaseModel):
    """Defines a ConfigMap requirement for an application (e.g. for config files)."""

    name: str
    data: Dict[str, str]
    mount_path: Optional[str] = None


class StorageTier(str, Enum):
    EPHEMERAL = "ephemeral"  # Transient data, no backup
    PERSISTENT = "persistent"  # Critical data, 3-2-1 eligible
    EXTERNAL = "external"  # NAS / S3 / External volumes


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
    external_source: Optional[str] = None  # e.g. "s3://bucket-name" or "nfs://nas/path"


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
    access_key_id: Optional[str] = None  # Secret resource name
    secret_access_key: Optional[str] = None  # Secret resource name
    region: str = "us-east-1"
    schedule: str = "0 0 2 * * *"  # Default 2 AM daily


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
    requires_extended_timeout: bool = Field(
        default=False,
        description="Set to true if the app takes a long time to start (e.g., heavy database or init processes).",
    )
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


class ProvisioningMethod(str, Enum):
    """How the app handles user identity from Authentik."""

    OIDC = (
        "oidc"  # App does its own OIDC flow with Authentik (inside the proxy boundary)
    )
    HEADER = "header"  # App reads X-Authentik-* headers injected by the proxy
    NONE = "none"  # No auto-provisioning (internal/infrastructure apps)


class ProvisioningConfig(BaseModel):
    """Configuration for automatic user provisioning via Authentik."""

    method: ProvisioningMethod = ProvisioningMethod.NONE
    auto_create: bool = Field(
        True, description="Auto-create user accounts on first login"
    )
    group_sync: bool = Field(
        False, description="Sync Authentik groups to the application"
    )
    name: Optional[str] = Field(
        None, description="Custom Authentik provider name to avoid naming conflicts"
    )
    redirect_uris: List[str] = Field(
        default_factory=list,
        description="Custom OIDC redirect URIs (overrides convention-based defaults)",
    )
    scopes: List[str] = Field(
        default_factory=lambda: ["openid", "profile", "email"],
        description="OIDC scopes to request",
    )
    client_id: Optional[str] = Field(
        None, description="Override auto-generated client_id"
    )
    client_secret_key: Optional[str] = Field(
        None,
        description="Doppler key name for the client secret (auto-generated if not set)",
    )


class HomepageConfig(BaseModel):
    """Configuration for Homepage dashboard integration."""

    enabled: bool = True
    icon: Optional[str] = None
    widget: Optional[Dict[str, Any]] = (
        None  # e.g., {"type": "nextcloud", "url": "...", "key": "..."}
    )
    group: Optional[str] = None
    weight: int = 0
    description: Optional[str] = None


class AppModel(BaseModel):
    """Unified configuration for a single application."""

    name: str = Field(..., description="Internal name of the application")
    service_name: Optional[str] = Field(
        None, description="Kubernetes service name (defaults to name)"
    )
    namespace: str = Field("default", description="Kubernetes namespace")
    port: int = Field(80, description="Service port")
    hostname: Optional[str] = Field(None, description="Exposed hostname")
    owner: Optional[str] = Field(
        None, description="Optional owner (user name) for private storage"
    )
    mode: ExposureMode = Field(ExposureMode.INTERNAL)
    category: AppCategory = Field(AppCategory.INTERNAL)
    tier: AppTier = Field(AppTier.STANDARD)
    clusters: List[str] = Field(default_factory=lambda: ["oci", "local"])
    dependencies: List[str] = Field(default_factory=list)
    auth: bool = Field(False, description="Enable authentication proxy (Authentik)")
    provisioning: Optional[ProvisioningConfig] = Field(
        None, description="Auto-provisioning configuration (OIDC/Header)"
    )
    auth_groups: List[str] = Field(default_factory=list)
    homepage: Optional[HomepageConfig] = Field(default_factory=HomepageConfig)
    storage: List[StorageConfig] = Field(default_factory=list)
    database: Optional[DatabaseConfig] = None
    secrets: List[SecretRequirement] = Field(default_factory=list)
    config_maps: List[ConfigMapRequirement] = Field(default_factory=list)
    values: Dict[str, Any] = Field(
        default_factory=dict, description="Custom Helm values (legacy/fallback)"
    )
    values_file: Optional[str] = Field(None, description="Path to external values file")
    helm: Optional[HelmConfig] = None
    chart: Optional[str] = Field(
        None, description="Helm chart name (legacy, use helm.chart instead)"
    )
    repo: Optional[str] = Field(None, description="Helm repository URL (legacy)")
    version: Optional[str] = Field(None, description="Helm chart version (legacy)")

    disable_auto_route: bool = Field(
        False, description="Disable automatic Route/Ingress generation"
    )
    allow_external: bool = Field(
        False, description="Allow external internet access (egress to 0.0.0.0/0)"
    )
    inject_secrets: bool = Field(
        True, description="Automatically inject defined secrets and imagePullSecrets"
    )
    auto_secrets: Dict[str, Dict[str, int]] = Field(
        default_factory=dict,
        description="Auto-generate local passwords (SecretName -> {EnvVarName -> Length})",
    )
    extra_env: Dict[str, str] = Field(
        default_factory=dict, description="Additional environment variables to inject"
    )
    skip_crds: bool = Field(
        False, description="Skip CRD installation in Helm charts (managed externally)"
    )
    monitoring: bool = Field(
        True, description="Enable automatic ServiceMonitor generation"
    )
    replicas: int = Field(1, description="Number of replicas (affects PDB generation)")
    resources: ResourceRequirements = Field(default_factory=ResourceRequirements)
    termination_grace_period: int = Field(
        30, description="Termination grace period in seconds"
    )
    test: TestConfig = Field(default_factory=TestConfig)
    database_backup: BackupDestination = Field(default_factory=BackupDestination)

    @model_validator(mode="after")
    def auto_enable_auth_for_protected(self) -> "AppModel":
        """Automatically enable auth proxy when mode is protected."""
        if self.mode == ExposureMode.PROTECTED and not self.auth:
            self.auth = True
        return self

    @model_validator(mode="after")
    def validate_image_registries(self) -> "AppModel":
        """Ensure all image repositories are fully qualified (contain a registry)."""
        helm = self.helm
        if not helm or not helm.values:
            return self

        def check_values(d: Any):
            if isinstance(d, dict):
                # Check if this dict has both 'registry' and 'repository' keys
                registry = d.get("registry", "")
                repository = d.get("repository", "")

                if repository and isinstance(repository, str):
                    # If registry is explicitly set, the image is properly qualified
                    if registry and isinstance(registry, str):
                        return  # Valid: registry + repository

                    # Otherwise validate the repository format
                    if "/" not in repository:
                        raise ValueError(
                            f"Image repository '{repository}' in app '{self.name}' must be fully qualified (e.g., docker.io/library/nginx)"
                        )

                    parts = repository.split("/")
                    reg = parts[0]
                    if "." not in reg and reg not in [
                        "localhost",
                        "docker.io",
                        "ghcr.io",
                        "quay.io",
                        "registry.hub.docker.com",
                    ]:
                        raise ValueError(
                            f"Image repository '{repository}' in app '{self.name}' must start with a valid registry (e.g., docker.io/...)"
                        )

                # Recursively check nested values
                for k, v in d.items():
                    if k not in ["registry", "repository"]:
                        check_values(v)
            elif isinstance(d, list):
                for item in d:
                    check_values(item)

        if not self.helm or not self.helm.values:
            return self

        check_values(self.helm.values)
        return self


class IdentityGroupModel(BaseModel):
    """Configuration for an identity group."""

    name: str
    members: List[str] = Field(default_factory=list)
    is_superuser: bool = Field(
        False, description="Map to Authentik superuser permissions"
    )


class IdentityUserModel(BaseModel):
    """Configuration for an identity user."""

    name: str
    display_name: Optional[str] = None
    email: Optional[str] = None
    groups: List[str] = Field(default_factory=list)
    attributes: Dict[str, Any] = Field(
        default_factory=dict, description="Custom Authentik attributes"
    )


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
    purpose: str = Field(
        "general", description="Semantic use: 'backup', 'media', 'archive'..."
    )
    tier: Literal["Standard", "InfrequentAccess", "Archive"] = Field(
        "Standard", description="Storage tier (providers map this to their own tiers)"
    )
    region: Optional[str] = Field(
        None, description="Override region for this bucket (default from stack config)"
    )
    export_as: Optional[str] = Field(
        None, description="Stack output key to expose the endpoint URL"
    )
    # Provider-specific credentials (Doppler key names)
    access_key_secret: str = Field(
        "OCI_S3_ACCESS_KEY", description="Doppler key for S3 Access Key ID"
    )
    secret_key_secret: str = Field(
        "OCI_S3_SECRET_KEY", description="Doppler key for S3 Secret Key"
    )
    # Endpoint override (for GENERIC provider or custom OCI namespace)
    endpoint_url: Optional[str] = Field(
        None, description="Override endpoint (required for provider=generic)"
    )
    tags: Dict[str, str] = Field(default_factory=dict)
    protect: bool = Field(
        True, description="Prevent accidental bucket deletion (recommended for backups)"
    )


class HomelabStackConfig(BaseModel):
    """Global configuration for the homelab stack."""

    domain: str = "smadja.dev"
    clusterName: str = "homelab"
    enableEnvoyGateway: bool = True
    enableMonitoring: bool = True
    enableLonghorn: bool = False
    renderYamlToDirectory: Optional[str] = Field(
        None, description="Native Pulumi YAML generation path"
    )
    apps: List[AppModel] = Field(default_factory=list)
    identities: IdentitiesModel = Field(default_factory=list)
    buckets: List[S3BucketConfig] = Field(
        default_factory=list, description="S3-compatible buckets to provision"
    )
