"""
Storage Provisioner Strategy / Factory Pattern
Delegates PVC and related secret creation based on the desired StorageAccess.
"""

import pulumi
import pulumi_kubernetes as k8s
from typing import Dict, List
from shared.utils.schemas import AppModel, StorageConfig, StorageAccess, StorageTier


class BaseStorageProvisioner:
    def provision(
        self,
        app: AppModel,
        storage: StorageConfig,
        idx: int,
        provider: k8s.Provider,
        parent: pulumi.Resource,
        **kwargs,
    ) -> List[pulumi.Resource]:
        raise NotImplementedError("Subclasses must implement provision")

    def _get_standard_labels(self, app: AppModel) -> Dict[str, str]:
        return {
            "app.kubernetes.io/name": app.name,
            "app.kubernetes.io/instance": app.name,
            "app.kubernetes.io/managed-by": "pulumi",
            "app.kubernetes.io/part-of": "homelab",
            "homelab.dev/tier": app.tier.value,
            "homelab.dev/category": app.category.value,
        }

    def _get_access_modes(self, storage: StorageConfig) -> List[str]:
        if storage.access in [StorageAccess.SHARED, StorageAccess.PRIVATE_SMB]:
            return ["ReadWriteMany"]
        return ["ReadWriteOnce"]


class DefaultProvisioner(BaseStorageProvisioner):
    def provision(
        self,
        app: AppModel,
        storage: StorageConfig,
        idx: int,
        provider: k8s.Provider,
        parent: pulumi.Resource,
        **kwargs,
    ) -> List[pulumi.Resource]:
        sc = storage.storage_class
        if not sc:
            if storage.tier == StorageTier.EPHEMERAL:
                sc = "local-path"
            elif storage.tier == StorageTier.EXTERNAL:
                sc = "nfs-client"
            else:
                sc = "local-path"

        pvc_name = f"{app.name}-{storage.name}"
        labels = self._get_standard_labels(app)
        if storage.backup_321:
            labels["homelab.dev/backup"] = "321"

        # Add Helm annotations to enable Helm adoption
        # This prevents "invalid ownership metadata" errors when Helm tries to manage
        # a PVC created by Pulumi
        annotations = {
            "meta.helm.sh/release-name": app.name,
            "meta.helm.sh/release-namespace": app.namespace,
        }

        pvc = k8s.core.v1.PersistentVolumeClaim(
            f"pvc-{app.name}-{idx}",
            metadata={
                "name": pvc_name,
                "namespace": app.namespace,
                "labels": labels,
                "annotations": annotations,
            },
            spec={
                "accessModes": self._get_access_modes(storage),
                "resources": {"requests": {"storage": storage.size}},
                "storageClassName": sc,
            },
            opts=pulumi.ResourceOptions(provider=provider, parent=parent),
        )
        return [pvc]


class HetznerSMBProvisioner(BaseStorageProvisioner):
    def provision(
        self,
        app: AppModel,
        storage: StorageConfig,
        idx: int,
        provider: k8s.Provider,
        parent: pulumi.Resource,
        **kwargs,
    ) -> List[pulumi.Resource]:
        pvc_name = f"{app.name}-{storage.name}"
        static_pv_name = f"pv-{app.name}-{storage.name}"

        # Si un PV statique est déclaré dans k8s-storage, créer uniquement le PVC
        # qui pointe vers ce PV (volumeName). Pas de StorageClass dynamique.
        pvc = k8s.core.v1.PersistentVolumeClaim(
            f"pvc-{app.name}-{idx}",
            metadata={
                "name": pvc_name,
                "namespace": app.namespace,
                "labels": self._get_standard_labels(app),
                "annotations": {
                    "meta.helm.sh/release-name": app.name,
                    "meta.helm.sh/release-namespace": app.namespace,
                },
            },
            spec={
                "accessModes": ["ReadWriteMany"],
                "storageClassName": "hetzner-smb",
                "volumeName": static_pv_name,  # ← lien vers le PV statique
                "resources": {"requests": {"storage": storage.size}},
            },
            opts=pulumi.ResourceOptions(provider=provider, parent=parent),
        )
        return [pvc]


class StorageProvisionerFactory:
    @staticmethod
    def get_provisioner(storage: StorageConfig) -> BaseStorageProvisioner:
        if storage.storage_class == "hetzner-smb":
            return HetznerSMBProvisioner()
        return DefaultProvisioner()
