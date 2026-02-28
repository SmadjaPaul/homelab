import pytest
import pulumi
from utils.schemas import AppModel, StorageConfig, StorageAccess, StorageTier, AppCategory
from apps.common.storage_provisioner import StorageProvisionerFactory, DefaultProvisioner, HetznerSMBProvisioner

class MockProvider:
    pass

class MockResource:
    pass

def test_default_provisioner_access_modes():
    # Test ReadWriteOnce
    storage_private = StorageConfig(
        name="data",
        tier=StorageTier.PERSISTENT,
        access=StorageAccess.PRIVATE,
        size="1Gi"
    )
    provisioner = StorageProvisionerFactory.get_provisioner(storage_private)
    assert isinstance(provisioner, DefaultProvisioner)
    assert provisioner._get_access_modes(storage_private) == ["ReadWriteOnce"]

    # Test ReadWriteMany (Shared)
    storage_shared = StorageConfig(
        name="data_shared",
        tier=StorageTier.PERSISTENT,
        access=StorageAccess.SHARED,
        size="1Gi"
    )
    assert provisioner._get_access_modes(storage_shared) == ["ReadWriteMany"]

def test_hetzner_provisioner_creation():
    storage_hetzner = StorageConfig(
        name="data",
        tier=StorageTier.EXTERNAL,
        access=StorageAccess.SHARED,
        storage_class="hetzner-smb",
        size="1Ti"
    )
    provisioner = StorageProvisionerFactory.get_provisioner(storage_hetzner)
    assert isinstance(provisioner, HetznerSMBProvisioner)
    assert provisioner._get_access_modes(storage_hetzner) == ["ReadWriteMany"]

def test_hetzner_private_smb_access_modes():
    storage_hetzner_private = StorageConfig(
        name="data",
        tier=StorageTier.EXTERNAL,
        access=StorageAccess.PRIVATE_SMB,
        storage_class="hetzner-smb",
        size="1Ti"
    )
    provisioner = StorageProvisionerFactory.get_provisioner(storage_hetzner_private)
    assert isinstance(provisioner, HetznerSMBProvisioner)
    assert provisioner._get_access_modes(storage_hetzner_private) == ["ReadWriteMany"]
