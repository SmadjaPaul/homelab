"""
StorageBoxOrchestrator — provisions sub-accounts, secrets, and PVs/PVCs
for the Hetzner Storage Box based on the `storagebox` section in apps.yaml.

Replaces the imperative SMB_APP_ACCOUNTS + make_smb_pv pattern in
k8s-storage/__main__.py.
"""

import pulumi
import pulumi_hcloud as hcloud
import pulumi_kubernetes as k8s
import pulumi_random as random
from typing import Optional

from shared.utils.schemas import StorageBoxConfig, StorageBoxAccount, StorageBoxVolume


class StorageBoxOrchestrator(pulumi.ComponentResource):
    """
    Reads StorageBoxConfig and provisions:
    - One RandomPassword + StorageBoxSubaccount + K8s Secret per sub-account
    - One PV + PVC per volume (with delete_before_replace=True)
    - One ExternalSecret + PVs/PVCs for the main account
    """

    def __init__(
        self,
        name: str,
        hostname: str,
        storage_box_id: int,
        config: StorageBoxConfig,
        provider: k8s.Provider,
        opts: Optional[pulumi.ResourceOptions] = None,
    ):
        super().__init__("homelab:common:StorageBoxOrchestrator", name, {}, opts)

        self._hostname = hostname
        self._storage_box_id = storage_box_id
        self._provider = provider

        # Provision each sub-account and its volumes
        for account in config.accounts:
            self._provision_account(account)

        # Provision the main account ExternalSecret + volumes
        if config.main_account:
            self._provision_main_account(config.main_account)

    # -------------------------------------------------------------------------
    # Private helpers
    # -------------------------------------------------------------------------

    def _smb_source(
        self,
        volume: StorageBoxVolume,
        home_directory: str,
        username: Optional[pulumi.Input[str]] = None,
    ) -> pulumi.Output[str]:
        """Build the full SMB source URL for a given volume and username.

        For StorageBox, the most reliable share name is the username itself.
        For sub-accounts, the hostname is '<username>.your-storagebox.de'.
        """
        path = volume.smb_path.strip("/")

        if username is not None:
            return pulumi.Output.from_input(username).apply(
                lambda u: f"//{u}.your-storagebox.de/{u}/{path}"
            )

        # Main account: extract username from hostname (uXXXXXX.your-storagebox.de)
        main_user = self._hostname.split(".")[0]
        return pulumi.Output.from_input(f"//{self._hostname}/{main_user}/{path}")

    def _make_pv_pvc(
        self,
        volume: StorageBoxVolume,
        secret_name: str,
        home_directory: str,
        parent: pulumi.Resource,
        username: Optional[str] = None,
    ):
        """Create a static PV + PVC pair for an SMB volume."""
        pv = k8s.core.v1.PersistentVolume(
            f"pv-{volume.pv_name}",
            metadata={"name": volume.pv_name},
            spec={
                "capacity": {"storage": volume.size},
                "accessModes": ["ReadWriteMany"],
                "persistentVolumeReclaimPolicy": "Retain",
                "storageClassName": "hetzner-smb",
                "mountOptions": [
                    "dir_mode=0777",
                    "file_mode=0777",
                    "uid=1000",
                    "gid=1000",
                    "noperm",
                    "mfsymlinks",
                    "cache=none",
                    "vers=3.0",
                    "nobrl",
                ],
                "csi": {
                    "driver": "smb.csi.k8s.io",
                    "readOnly": False,
                    "volumeHandle": volume.pv_name,
                    "volumeAttributes": {
                        "source": self._smb_source(volume, home_directory, username),
                    },
                    "nodeStageSecretRef": {
                        "name": secret_name,
                        "namespace": "kube-system",
                    },
                },
            },
            opts=pulumi.ResourceOptions(
                provider=self._provider,
                parent=parent,
                delete_before_replace=True,
            ),
        )

        k8s.core.v1.PersistentVolumeClaim(
            f"pvc-static-{volume.pv_name}",
            metadata={"name": volume.pvc_name, "namespace": volume.namespace},
            spec={
                "accessModes": ["ReadWriteMany"],
                "storageClassName": "hetzner-smb",
                "volumeName": volume.pv_name,
                "resources": {"requests": {"storage": volume.size}},
            },
            opts=pulumi.ResourceOptions(
                provider=self._provider,
                parent=pv,
                depends_on=[pv],
            ),
        )

    def _provision_account(self, account: StorageBoxAccount):
        """Provision a sub-account: password → Hetzner sub-account → K8s secret → PVs."""
        password = random.RandomPassword(
            f"storagebox-app-pass-{account.name}",
            length=16,
            special=True,
            override_special="!@#$%^&*()-_=+",
            min_upper=1,
            min_lower=1,
            min_numeric=1,
            min_special=1,
            opts=pulumi.ResourceOptions(parent=self),
        )

        sub_account = hcloud.StorageBoxSubaccount(
            f"storagebox-app-{account.name}",
            storage_box_id=self._storage_box_id,
            home_directory=account.home_directory,
            password=password.result,
            access_settings=hcloud.StorageBoxSubaccountAccessSettingsArgs(
                samba_enabled=True,
                ssh_enabled=False,
                webdav_enabled=True,
                reachable_externally=True,
            ),
            opts=pulumi.ResourceOptions(parent=self),
        )

        secret_name = f"smb-{account.name}"
        k8s.core.v1.Secret(
            f"secret-smb-{account.name}",
            metadata={
                "name": secret_name,
                "namespace": "kube-system",
            },
            string_data={
                "username": sub_account.username,
                "password": password.result,
            },
            opts=pulumi.ResourceOptions(
                provider=self._provider,
                parent=sub_account,
            ),
        )

        for volume in account.volumes:
            self._make_pv_pvc(
                volume,
                secret_name,
                home_directory=account.home_directory,
                parent=sub_account,
                username=sub_account.username,
            )

    def _provision_main_account(self, main_account):
        """Provision the ExternalSecret for the main account + its volumes."""
        external_secret = k8s.apiextensions.CustomResource(
            "secret-smb-nextcloud",
            api_version="external-secrets.io/v1beta1",
            kind="ExternalSecret",
            metadata={"name": main_account.secret_name, "namespace": "kube-system"},
            spec={
                "refreshInterval": "1h",
                "secretStoreRef": {"name": "doppler", "kind": "ClusterSecretStore"},
                "target": {"name": main_account.secret_name, "creationPolicy": "Owner"},
                "data": [
                    {
                        "secretKey": "username",
                        "remoteRef": {"key": main_account.doppler_user_key},
                    },
                    {
                        "secretKey": "password",
                        "remoteRef": {"key": main_account.doppler_pass_key},
                    },
                ],
            },
            opts=pulumi.ResourceOptions(provider=self._provider, parent=self),
        )

        for volume in main_account.volumes:
            self._make_pv_pvc(
                volume,
                main_account.secret_name,
                home_directory="",
                parent=external_secret,
            )
