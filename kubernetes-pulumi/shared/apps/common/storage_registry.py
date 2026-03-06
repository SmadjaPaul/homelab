import pulumi
import pulumi_kubernetes as k8s
from typing import List, Dict, Any, Optional

from shared.utils.schemas import AppModel
from shared.apps.common.storagebox import setup_storagebox_automation, StorageBoxManager
from shared.apps.common.storage_provisioner import StorageProvisionerFactory


class StorageRegistry:
    def __init__(
        self,
        provider: k8s.Provider,
        config: Dict[str, Any],
        parent: pulumi.ComponentResource,
    ):
        self.provider = provider
        self.config = config
        self.parent = parent
        self._hetzner_smb_ready = False
        self.storagebox_manager: Optional[StorageBoxManager] = None

    def setup_storagebox_automation(self):
        pulumi_config = pulumi.Config("hetzner")
        storage_box_id = pulumi_config.get_int("storage_box_id") or self.config.get(
            "hcloud_storage_box_id"
        )

        identities = self.config.get("identities")
        if not identities:
            return

        users = (
            identities.users
            if hasattr(identities, "users")
            else identities.get("users")
        )
        if not users:
            return

        self.storagebox_manager = setup_storagebox_automation(
            provider=self.provider,
            storage_box_id=storage_box_id,
            users=users,
        )

    def setup_hetzner_smb_resources(
        self,
        deployed_apps: Optional[Dict[str, Any]] = None,
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> List[pulumi.Resource]:
        if self._hetzner_smb_ready:
            return []

        deps = []
        if (
            deployed_apps
            and "external-secrets" in deployed_apps
            and isinstance(deployed_apps["external-secrets"], pulumi.Resource)
        ):
            deps.append(deployed_apps["external-secrets"])

        local_opts = (
            opts
            if opts
            else pulumi.ResourceOptions(provider=self.provider, parent=self.parent)
        )
        if deps:
            local_opts = pulumi.ResourceOptions.merge(
                local_opts, pulumi.ResourceOptions(depends_on=deps)
            )

        es = k8s.apiextensions.CustomResource(
            "hetzner-storage-creds-global",
            api_version="external-secrets.io/v1beta1",
            kind="ExternalSecret",
            metadata={
                "name": "hetzner-storage-creds",
                "namespace": "kube-system",
                "annotations": {"pulumi.com/patchForce": "true"},
            },
            spec={
                "refreshInterval": "1h",
                "secretStoreRef": {
                    "kind": "ClusterSecretStore",
                    "name": "doppler",
                },
                "target": {"name": "hetzner-storage-creds", "creationPolicy": "Owner"},
                "dataFrom": [{"extract": {"key": "HETZNER_STORAGE_BOX_1"}}],
            },
            opts=local_opts,
        )

        self._hetzner_smb_ready = True
        return [es]

    def setup_storage_for_app(
        self, app: AppModel, deployed_apps: Dict[str, Any], opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        resources = []
        for idx, storage in enumerate(app.storage):
            if getattr(storage, "existing_claim", None):
                pulumi.Output.from_input(app.name).apply(
                    lambda name, e=storage.existing_claim: print(
                        f"  [Registry] App {name} volume uses existing claim {e}"
                    )
                )
                continue

            provisioner = StorageProvisionerFactory.get_provisioner(storage)
            resources.extend(
                provisioner.provision(
                    app=app,
                    storage=storage,
                    idx=idx,
                    provider=self.provider,
                    parent=self.parent,
                    storagebox_manager=self.storagebox_manager,
                    setup_global_smb_callback=lambda: self.setup_hetzner_smb_resources(
                        deployed_apps, opts
                    ),
                )
            )
        return resources
