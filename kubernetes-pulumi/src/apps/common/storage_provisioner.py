"""
Storage Provisioner Strategy / Factory Pattern
Delegates PVC and related secret creation based on the desired StorageAccess.
"""
import pulumi
import pulumi_kubernetes as k8s
from typing import Optional, Dict, Any, List
from utils.schemas import AppModel, StorageConfig, StorageAccess, StorageTier

class BaseStorageProvisioner:
    def provision(self, app: AppModel, storage: StorageConfig, idx: int, provider: k8s.Provider, parent: pulumi.Resource, **kwargs) -> k8s.core.v1.PersistentVolumeClaim:
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
    def provision(self, app: AppModel, storage: StorageConfig, idx: int, provider: k8s.Provider, parent: pulumi.Resource, **kwargs) -> k8s.core.v1.PersistentVolumeClaim:
        sc = storage.storage_class
        if not sc:
            if storage.tier == StorageTier.EPHEMERAL:
                sc = "local-path"
            elif storage.tier == StorageTier.EXTERNAL:
                sc = "nfs-client"
            else:
                sc = "oci-bv"

        pvc_name = f"{app.name}-data-{idx}" if len(app.storage) > 1 else f"{app.name}-data"
        labels = self._get_standard_labels(app)
        if storage.backup_321:
            labels["homelab.dev/backup"] = "321"

        return k8s.core.v1.PersistentVolumeClaim(
            f"pvc-{app.name}-{idx}",
            metadata={
                "name": pvc_name,
                "namespace": app.namespace,
                "labels": labels,
            },
            spec={
                "accessModes": self._get_access_modes(storage),
                "resources": {"requests": {"storage": storage.size}},
                "storageClassName": sc,
            },
            opts=pulumi.ResourceOptions(provider=provider, parent=parent),
        )

class HetznerSMBProvisioner(BaseStorageProvisioner):
    def provision(self, app: AppModel, storage: StorageConfig, idx: int, provider: k8s.Provider, parent: pulumi.Resource, **kwargs) -> k8s.core.v1.PersistentVolumeClaim:
        pvc_name = f"{app.name}-music" if storage.name == "music" else f"{app.name}-data-{idx}"
        labels = self._get_standard_labels(app)
        if storage.backup_321:
            labels["homelab.dev/backup"] = "321"

        # Smb secret logic
        smb_secret_name = None
        storagebox_manager = kwargs.get('storagebox_manager')
        setup_global_smb = kwargs.get('setup_global_smb_callback')

        if storage.access == StorageAccess.PRIVATE_SMB and storagebox_manager:
            smb_secret_name = storagebox_manager.get_secret_name_for_user(app.owner)
            if not smb_secret_name:
                pulumi.log.warn(f"App {app.name} requests private SMB for owner {app.owner}, but no StorageBox sub-account found for this user.")
                if setup_global_smb:
                    setup_global_smb()
                smb_secret_name = "hetzner-storage-creds"
        else:
            if setup_global_smb:
                setup_global_smb()
            smb_secret_name = "hetzner-storage-creds"

        return k8s.core.v1.PersistentVolumeClaim(
            f"pvc-{app.name}-{idx}",
            metadata={
                "name": pvc_name,
                "namespace": app.namespace,
                "labels": labels,
            },
            spec={
                "accessModes": self._get_access_modes(storage),
                "resources": {"requests": {"storage": storage.size}},
                "storageClassName": storage.storage_class,
            },
            opts=pulumi.ResourceOptions(provider=provider, parent=parent),
        )

class StorageProvisionerFactory:
    @staticmethod
    def get_provisioner(storage: StorageConfig) -> BaseStorageProvisioner:
        if storage.storage_class == "hetzner-smb":
            return HetznerSMBProvisioner()
        return DefaultProvisioner()
