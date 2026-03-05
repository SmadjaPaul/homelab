"""
Hetzner Storage Box Manager (Pulumi HCloud Provider)

Provisions sub-accounts for Hetzner Storage Boxes using the official
Pulumi HCloud provider (hcloud.StorageBoxSubaccount).
"""

import pulumi
import pulumi_hcloud as hcloud
import pulumi_kubernetes as k8s
import pulumi_random as random
from typing import List, Dict, Optional
from shared.utils.schemas import IdentityUserModel


class StorageBoxManager(pulumi.ComponentResource):
    """
    Manages Hetzner Storage Box sub-accounts via the Pulumi HCloud provider.
    """

    def __init__(
        self,
        name: str,
        provider: k8s.Provider,
        storage_box_id: int,
        users: List[IdentityUserModel],
        opts: Optional[pulumi.ResourceOptions] = None,
    ):
        super().__init__("homelab:common:StorageBoxManager", name, {}, opts)

        self.provider = provider
        self.storage_box_id = storage_box_id
        self.sub_accounts: Dict[str, hcloud.StorageBoxSubaccount] = {}

        self._provision_sub_accounts(users)

    def _provision_sub_accounts(self, users: List[IdentityUserModel]):
        """
        For each user, create a StorageBoxSubaccount resource and store
        credentials in a Kubernetes secret.
        """
        for user in users:
            # Handle both model objects and dicts
            user_name = user.name if hasattr(user, "name") else user.get("name")
            if not user_name:
                continue

            # 1. Generate a secure random password for the sub-account
            password = random.RandomPassword(
                f"storagebox-sub-pass-{user_name}",
                length=16,
                special=True,
                override_special="!@#$%^&*()-_=+",  # Safe specials for SMB
                min_upper=1,
                min_lower=1,
                min_numeric=1,
                min_special=1,
                opts=pulumi.ResourceOptions(parent=self),
            )

            # 2. Create Storage Box Sub-account via official Pulumi HCloud provider
            sub_account = hcloud.StorageBoxSubaccount(
                f"storagebox-sub-{user_name}",
                storage_box_id=self.storage_box_id,
                home_directory=user_name,
                password=password.result,
                # Enable required protocols and external access for OCI
                access_settings=hcloud.StorageBoxSubaccountAccessSettingsArgs(
                    samba_enabled=True,
                    ssh_enabled=True,
                    webdav_enabled=True,
                    reachable_externally=True,
                ),
                opts=pulumi.ResourceOptions(parent=self),
            )
            self.sub_accounts[user_name] = sub_account

            # 3. Create a Kubernetes secret for the sub-account
            # The CSI driver needs username and password
            k8s.core.v1.Secret(
                f"secret-storage-{user_name}",
                metadata={
                    "name": f"hetzner-storage-{user_name}",
                    "namespace": "kube-system",  # CSI driver looks here
                },
                string_data={
                    "username": sub_account.username,
                    "password": password.result,
                },
                opts=pulumi.ResourceOptions(provider=self.provider, parent=sub_account),
            )

    def get_secret_name_for_user(self, user_name: Optional[str]) -> Optional[str]:
        """Return the K8s secret name for a given user sub-account."""
        if not user_name or user_name not in self.sub_accounts:
            return None
        return f"hetzner-storage-{user_name}"


def setup_storagebox_automation(
    provider: k8s.Provider,
    storage_box_id: Optional[int],
    users: List[IdentityUserModel],
) -> Optional[StorageBoxManager]:
    """Helper to initialize StorageBoxManager."""
    if not storage_box_id:
        print(
            "  [StorageBox] Warning: No storage_box_id provided. Skipping sub-account automation."
        )
        return None

    return StorageBoxManager(
        "storagebox-automation",
        provider=provider,
        storage_box_id=storage_box_id,
        users=users,
    )
