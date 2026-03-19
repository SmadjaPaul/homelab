"""
Static tests for the storagebox section in apps.yaml.
Validates structural consistency without any cluster access.
"""

import pytest
from pathlib import Path
import yaml

from shared.utils.schemas import StorageBoxConfig


APPS_YAML = Path(__file__).parent.parent.parent / "apps.yaml"


@pytest.fixture(scope="module")
def raw_config():
    with open(APPS_YAML) as f:
        return yaml.safe_load(f)


@pytest.fixture(scope="module")
def storagebox(raw_config):
    data = raw_config.get("storagebox")
    assert data is not None, "storagebox section missing from apps.yaml"
    return StorageBoxConfig(**data)


def test_storagebox_hostname_present(raw_config):
    """hcloud_storage_box_hostname must be declared."""
    assert "hcloud_storage_box_hostname" in raw_config, (
        "hcloud_storage_box_hostname missing from apps.yaml"
    )
    hostname = raw_config["hcloud_storage_box_hostname"]
    assert hostname and "your-storagebox.de" in hostname


def test_pv_names_unique(storagebox):
    """All pv_name values across all accounts must be globally unique."""
    pv_names = []
    for account in storagebox.accounts:
        for vol in account.volumes:
            pv_names.append(vol.pv_name)
    if storagebox.main_account:
        for vol in storagebox.main_account.volumes:
            pv_names.append(vol.pv_name)
    assert len(pv_names) == len(set(pv_names)), (
        f"Duplicate pv_name(s): {[n for n in pv_names if pv_names.count(n) > 1]}"
    )


def test_pvc_names_unique(storagebox):
    """All pvc_name values across all accounts must be globally unique."""
    pvc_names = []
    for account in storagebox.accounts:
        for vol in account.volumes:
            pvc_names.append(vol.pvc_name)
    if storagebox.main_account:
        for vol in storagebox.main_account.volumes:
            pvc_names.append(vol.pvc_name)
    assert len(pvc_names) == len(set(pvc_names)), (
        f"Duplicate pvc_name(s): {[n for n in pvc_names if pvc_names.count(n) > 1]}"
    )


def test_smb_paths_start_with_slash(storagebox):
    """Every smb_path must start with /."""
    for account in storagebox.accounts:
        for vol in account.volumes:
            assert vol.smb_path.startswith("/"), (
                f"smb_path '{vol.smb_path}' in account '{account.name}' must start with '/'"
            )
    if storagebox.main_account:
        for vol in storagebox.main_account.volumes:
            assert vol.smb_path.startswith("/"), (
                f"smb_path '{vol.smb_path}' in main_account must start with '/'"
            )


def test_home_directories_unique(storagebox):
    """No two sub-accounts should share the same home_directory."""
    home_dirs = [acc.home_directory for acc in storagebox.accounts]
    assert len(home_dirs) == len(set(home_dirs)), (
        f"Duplicate home_directory: {[d for d in home_dirs if home_dirs.count(d) > 1]}"
    )


def test_account_names_unique(storagebox):
    """Sub-account names must be unique."""
    names = [acc.name for acc in storagebox.accounts]
    assert len(names) == len(set(names)), (
        f"Duplicate account name(s): {[n for n in names if names.count(n) > 1]}"
    )


def test_each_account_has_at_least_one_volume(storagebox):
    """Every sub-account must declare at least one volume."""
    for account in storagebox.accounts:
        assert len(account.volumes) > 0, f"Account '{account.name}' has no volumes"
