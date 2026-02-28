"""
Hetzner Storage Box Manager
Provisions sub-accounts for users defined in identities and
exports credentials to Kubernetes secrets.
"""

from typing import List, Dict, Any, Optional
import pulumi
import pulumi_kubernetes as k8s
import pulumi_hcloud as hcloud
import pulumi_random as random
from utils.schemas import AppModel, IdentityUserModel

class StorageBoxManager(pulumi.ComponentResource):
    """
    Manages Hetzner Storage Box sub-accounts.
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
        self.users = users

        self.sub_accounts = {}
        self._provision_sub_accounts()

    def _provision_sub_accounts(self):
        """Provision a sub-account for each user and create a Kubernetes secret."""

        for user in self.users:
            if not user.name:
                continue

            # Generate a secure random password for the sub-account
            password = random.RandomPassword(
                f"storagebox-sub-pass-{user.name}",
                length=16,
                special=False, # SMB passwords can sometimes be picky with special chars
                opts=pulumi.ResourceOptions(parent=self),
            )

            # 1. Create Storage Box Sub-account
            sub_account = hcloud.StorageBoxSubaccount(
                f"storagebox-sub-{user.name}",
                storage_box_id=self.storage_box_id,
                description=f"Storage for user {user.name}",
                home_directory=user.name,
                password=password.result,
                # Sub-account permissions
                opts=pulumi.ResourceOptions(parent=self),
            )

            self.sub_accounts[user.name] = sub_account

            # 2. Create a Kubernetes secret for the sub-account
            # The CSI driver needs username and password
            secret_name = f"hetzner-storage-{user.name}"
            k8s.core.v1.Secret(
                f"secret-storage-{user.name}",
                metadata={
                    "name": secret_name,
                    "namespace": "kube-system", # CSI driver looks here
                },
                string_data={
                    "username": sub_account.username,
                    "password": password.result,
                },
                opts=pulumi.ResourceOptions(provider=self.provider, parent=sub_account),
            )

            print(f"  [StorageBox] Registered sub-account for user: {user.name}")

    def get_secret_name_for_user(self, user_name: Optional[str]) -> Optional[str]:
        """Return the K8s secret name for a given user sub-account."""
        if not user_name or user_name not in self.sub_accounts:
            return None
        return f"hetzner-storage-{user_name}"

def setup_storagebox_automation(
    provider: k8s.Provider,
    storage_box_id: Optional[int],
    users: List[IdentityUserModel]
) -> Optional[StorageBoxManager]:
    """Helper to initialize StorageBoxManager."""
    if not storage_box_id:
        print("  [StorageBox] Warning: No storage_box_id provided. Skipping sub-account automation.")
        return None

    return StorageBoxManager(
        "storagebox-automation",
        provider=provider,
        storage_box_id=storage_box_id,
        users=users
    )
