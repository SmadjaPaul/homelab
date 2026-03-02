"""
S3-compatible Storage Manager with multi-provider abstraction.

Supports:
- OCI Object Storage (Oracle Cloud, always-free tier)
- Cloudflare R2 (zero egress cost)
- Generic HTTP endpoint (self-hosted RustFS, MinIO, Garage, etc.)

Usage in apps.yaml:
    buckets:
      - name: homelab-db-backups
        provider: oci
        purpose: backup
        tier: InfrequentAccess
        export_as: db_backup_bucket

      - name: homelab-velero
        provider: oci
        purpose: backup
        export_as: velero_backup_bucket
        access_key_secret: OCI_S3_ACCESS_KEY
        secret_key_secret: OCI_S3_SECRET_KEY

      - name: smadja-media
        provider: cloudflare
        purpose: media
        export_as: media_bucket
        access_key_secret: CF_R2_ACCESS_KEY
        secret_key_secret: CF_R2_SECRET_KEY

      - name: local-rustfs-backup
        provider: generic
        endpoint_url: https://rustfs.local.smadja.dev
        purpose: backup
        export_as: local_backup_bucket
"""

from __future__ import annotations

import abc
from typing import Dict, List, Optional
import pulumi
from shared.utils.schemas import S3BucketConfig, S3Provider


# ---------------------------------------------------------------------------
# Data class: A resolved bucket endpoint (returned by drivers after creation)
# ---------------------------------------------------------------------------

class BucketEndpoint:
    """
    Holds all information needed by consuming stacks to interact with a bucket.
    All fields may be Pulumi Outputs (resolved at deploy time).
    """

    def __init__(
        self,
        name: str,
        endpoint_url: pulumi.Output,
        bucket_name: pulumi.Output,
        region: pulumi.Output,
        access_key_secret_name: str,  # Doppler key — not the value!
        secret_key_secret_name: str,  # Doppler key — not the value!
    ):
        self.name = name
        self.endpoint_url = endpoint_url
        self.bucket_name = bucket_name
        self.region = region
        self.access_key_secret_name = access_key_secret_name
        self.secret_key_secret_name = secret_key_secret_name

    def as_dict(self) -> pulumi.Output:
        """Returns a serializable Output[dict] for stack exports."""
        return pulumi.Output.all(
            endpoint_url=self.endpoint_url,
            bucket_name=self.bucket_name,
            region=self.region,
            access_key_secret_name=pulumi.Output.from_input(self.access_key_secret_name),
            secret_key_secret_name=pulumi.Output.from_input(self.secret_key_secret_name),
        ).apply(lambda args: {
            "endpoint_url": args["endpoint_url"],
            "bucket_name": args["bucket_name"],
            "region": args["region"],
            "access_key_secret_name": args["access_key_secret_name"],
            "secret_key_secret_name": args["secret_key_secret_name"],
        })


# ---------------------------------------------------------------------------
# Abstract base driver
# ---------------------------------------------------------------------------

class S3Driver(abc.ABC):
    """Base class for all S3 provider drivers."""

    @abc.abstractmethod
    def provision(self, cfg: S3BucketConfig, stack_region: str) -> BucketEndpoint:
        """
        Create (or import) the bucket defined in cfg.
        Returns a BucketEndpoint with all resolved connection details.
        """
        ...


# ---------------------------------------------------------------------------
# OCI Object Storage driver
# ---------------------------------------------------------------------------

class OciS3Driver(S3Driver):
    """
    Driver for Oracle Cloud Infrastructure Object Storage.

    Compatible with the S3 API via the OCI compatibility layer:
    https://<namespace>.compat.objectstorage.<region>.oraclecloud.com

    Required Pulumi config keys (set in Pulumi.*.yaml):
      homelab-k8s-storage:ociNamespace  — OCI object storage namespace
      homelab-k8s-storage:ociCompartmentId — OCI compartment OCID
    """

    # OCI storage tier mapping from our generic tiers
    _TIER_MAP = {
        "Standard": "Standard",
        "InfrequentAccess": "Standard",  # OCI 4.1.0 doesn't support InfrequentAccess as an enum value
        "Archive": "Archive",
    }

    def __init__(self, namespace: str, compartment_id: str):
        self.namespace = namespace
        self.compartment_id = compartment_id

    def provision(self, cfg: S3BucketConfig, stack_region: str) -> BucketEndpoint:
        try:
            import pulumi_oci as oci
        except ImportError:
            raise RuntimeError(
                "pulumi-oci is required for OCI S3 support. "
                "Run: uv add pulumi-oci in k8s-storage/"
            )

        region = cfg.region or stack_region
        oci_tier = self._TIER_MAP.get(cfg.tier, "Standard")

        bucket = oci.objectstorage.Bucket(
            f"s3-bucket-{cfg.name}",
            namespace=self.namespace,
            compartment_id=self.compartment_id,
            name=cfg.name,
            storage_tier=oci_tier,
            versioning="Disabled",
            freeform_tags={
                **cfg.tags,
                "managed-by": "pulumi",
                "purpose": cfg.purpose,
            },
            opts=pulumi.ResourceOptions(protect=cfg.protect),
        )

        endpoint_url = bucket.namespace.apply(
            lambda ns: f"https://{ns}.compat.objectstorage.{region}.oraclecloud.com"
        )

        return BucketEndpoint(
            name=cfg.name,
            endpoint_url=endpoint_url,
            bucket_name=bucket.name,
            region=pulumi.Output.from_input(region),
            access_key_secret_name=cfg.access_key_secret,
            secret_key_secret_name=cfg.secret_key_secret,
        )


# ---------------------------------------------------------------------------
# Cloudflare R2 driver
# ---------------------------------------------------------------------------

class CloudflareR2Driver(S3Driver):
    """
    Driver for Cloudflare R2 Object Storage.

    R2 exposes an S3-compatible API at:
    https://<account_id>.r2.cloudflarestorage.com

    No egress fees. Region is always "auto".

    Required Pulumi config key:
      homelab-k8s-storage:cloudflareAccountId — Cloudflare account ID
    """

    def __init__(self, account_id: str):
        self.account_id = account_id

    def provision(self, cfg: S3BucketConfig, stack_region: str) -> BucketEndpoint:
        try:
            import pulumi_cloudflare as cloudflare
        except ImportError:
            raise RuntimeError(
                "pulumi-cloudflare is required for R2 support. "
                "Run: uv add pulumi-cloudflare in k8s-storage/"
            )

        bucket = cloudflare.R2Bucket(
            f"s3-bucket-{cfg.name}",
            account_id=self.account_id,
            name=cfg.name,
            location="WEUR",  # Western Europe — adjust as needed
            opts=pulumi.ResourceOptions(protect=cfg.protect),
        )

        endpoint_url = pulumi.Output.from_input(
            f"https://{self.account_id}.r2.cloudflarestorage.com"
        )

        return BucketEndpoint(
            name=cfg.name,
            endpoint_url=endpoint_url,
            bucket_name=bucket.name,
            region=pulumi.Output.from_input("auto"),  # R2 doesn't use regions
            access_key_secret_name=cfg.access_key_secret,
            secret_key_secret_name=cfg.secret_key_secret,
        )


# ---------------------------------------------------------------------------
# Generic HTTP driver (RustFS, MinIO, Garage, etc.)
# ---------------------------------------------------------------------------

class GenericS3Driver(S3Driver):
    """
    Driver for any generic S3-compatible endpoint.

    Does NOT attempt to create the bucket via an API — it assumes the bucket
    already exists on the target service (e.g. RustFS) or will be created
    manually. This driver simply exports the connection details so that
    consuming applications can point at the right endpoint.

    Required config on the bucket:
      endpoint_url — full URL of the S3-compatible service
    """

    def provision(self, cfg: S3BucketConfig, stack_region: str) -> BucketEndpoint:
        if not cfg.endpoint_url:
            raise ValueError(
                f"Bucket '{cfg.name}' uses provider=generic but has no endpoint_url. "
                "Set endpoint_url in apps.yaml."
            )

        print(
            f"  [S3/Generic] Bucket '{cfg.name}' uses a generic endpoint. "
            f"No API call will be made — assuming bucket exists at {cfg.endpoint_url}."
        )

        return BucketEndpoint(
            name=cfg.name,
            endpoint_url=pulumi.Output.from_input(cfg.endpoint_url),
            bucket_name=pulumi.Output.from_input(cfg.name),
            region=pulumi.Output.from_input(cfg.region or stack_region or "local"),
            access_key_secret_name=cfg.access_key_secret,
            secret_key_secret_name=cfg.secret_key_secret,
        )


# ---------------------------------------------------------------------------
# Central S3Manager — orchestrates all drivers
# ---------------------------------------------------------------------------

class S3Manager:
    """
    Orchestrates S3 bucket provisioning across multiple providers.

    Usage:
        manager = S3Manager(
            buckets=config.buckets,
            stack_region="eu-paris-1",
            oci_namespace="axnvxxurxefp",
            oci_compartment_id="ocid1.tenancy.oc1..xxx",
            cloudflare_account_id="abc123...",
        )
        s3_endpoints = manager.provision_all()
        # s3_endpoints is a dict[export_as_key -> Output[dict]]
        # Export s3_endpoints from k8s-storage so k8s-apps can consume it.
    """

    def __init__(
        self,
        buckets: List[S3BucketConfig],
        stack_region: str = "eu-paris-1",
        # Provider config — only the relevant ones need to be set
        oci_namespace: Optional[str] = None,
        oci_compartment_id: Optional[str] = None,
        cloudflare_account_id: Optional[str] = None,
    ):
        self._buckets = buckets
        self._stack_region = stack_region

        # Build driver registry (lazy — only instantiate when needed)
        self._drivers: Dict[S3Provider, S3Driver] = {}

        if oci_namespace and oci_compartment_id:
            self._drivers[S3Provider.OCI] = OciS3Driver(
                namespace=oci_namespace,
                compartment_id=oci_compartment_id,
            )

        if cloudflare_account_id:
            self._drivers[S3Provider.CLOUDFLARE] = CloudflareR2Driver(
                account_id=cloudflare_account_id,
            )

        # Generic driver is always available (no credentials needed at init time)
        self._drivers[S3Provider.GENERIC] = GenericS3Driver()

    def provision_all(self) -> Dict[str, pulumi.Output]:
        """
        Provision all declared buckets.

        Returns a dict mapping each bucket's `export_as` key to an
        Output[dict] with {endpoint_url, bucket_name, region, access/secret key names}.
        """
        endpoints: Dict[str, pulumi.Output] = {}

        for cfg in self._buckets:
            print(f"  [S3Manager] Provisioning bucket '{cfg.name}' via provider={cfg.provider}...")

            driver = self._drivers.get(cfg.provider)
            if driver is None:
                raise ValueError(
                    f"No driver configured for provider '{cfg.provider}' "
                    f"(bucket: {cfg.name}). Make sure to pass the required "
                    f"credentials to S3Manager (e.g. oci_namespace for OCI)."
                )

            endpoint = driver.provision(cfg, self._stack_region)
            export_key = cfg.export_as or cfg.name
            endpoints[export_key] = endpoint.as_dict()
            print(f"  [S3Manager] Bucket '{cfg.name}' → export_as='{export_key}' ✓")

        return endpoints
