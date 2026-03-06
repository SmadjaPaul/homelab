import copy
from typing import Any

from shared.utils.schemas import AppModel


class HelmValuesAdapter:
    def __init__(self, model: AppModel):
        self.model = model

    def get_final_values(self) -> dict[str, Any]:
        """Provides the final dictionary of Helm values."""
        final_values = (
            copy.deepcopy(self.model.helm.values)
            if self.model.helm and self.model.helm.values
            else {}
        )

        self.apply_storage(final_values)
        self.apply_secrets(final_values)
        self.apply_image_pull_secrets(final_values)
        self.apply_database(final_values)
        self.apply_fullname_override(final_values)
        self.apply_extra_env(final_values)

        return final_values

    def apply_storage(self, final_values: dict[str, Any]):
        """Inject additional storage volumes created by the registry."""
        if not self.model.storage:
            return

        if "persistence" not in final_values:
            final_values["persistence"] = {}

        for storage in self.model.storage:
            key = storage.name
            pvc_name = (
                storage.existing_claim
                if hasattr(storage, "existing_claim") and storage.existing_claim
                else f"{self.model.name}-{storage.name}"
            )

            # Skip if already defined in manually provided values
            if key in final_values.get("persistence", {}):
                continue

            # Check if a similar key is already defined
            found_similar = False
            for existing_key in final_values.get("persistence", {}).keys():
                if key.lower() == existing_key.lower() or existing_key.lower().endswith(
                    key.lower()
                ):
                    found_similar = True
                    break
            if found_similar:
                continue

            self._inject_storage(final_values, key, pvc_name, storage.mount_path)

    def _inject_storage(
        self, final_values: dict[str, Any], key: str, pvc_name: str, mount_path: str
    ):
        """Standard PVC injection style."""
        final_values["persistence"][key] = {
            "enabled": True,
            "type": "pvc",
            "existingClaim": pvc_name,
            "mountPath": mount_path,
        }

    def apply_secrets(self, final_values: dict[str, Any]):
        """Automatically inject defined secrets via envFrom."""
        if not self.model.secrets or not self.model.inject_secrets:
            return

        env_from_item = [
            {"secretRef": {"name": req.name}} for req in self.model.secrets
        ]
        self._inject_env_from(final_values, env_from_item)

    def _inject_env_from(self, final_values: dict[str, Any], env_from_item: list):
        """Standard envFrom injection for secrets."""
        if "global" not in final_values:
            final_values["global"] = {}
        if "envFrom" not in final_values["global"]:
            final_values["global"]["envFrom"] = []
        final_values["global"]["envFrom"].extend(env_from_item)

        if "controllers" in final_values:
            for ctrl_val in final_values["controllers"].values():
                if "containers" in ctrl_val:
                    for cont_val in ctrl_val["containers"].values():
                        if "envFrom" not in cont_val:
                            cont_val["envFrom"] = []
                        cont_val["envFrom"].extend(env_from_item)

    def inject_config_secret(
        self, final_values: dict[str, Any], secret_ref: dict[str, Any]
    ):
        """Inject unified Config Secret via envFrom generated during deploy_components."""
        self._inject_env_from(final_values, [secret_ref])

    def apply_image_pull_secrets(self, final_values: dict[str, Any]):
        """Inject imagePullSecrets for private images."""
        if self.model.inject_secrets and "imagePullSecrets" not in final_values:
            final_values["imagePullSecrets"] = [{"name": "dockerhub-secret"}]

    def apply_database(self, final_values: dict[str, Any]):
        """Inject local database connection info."""
        if not self.model.database or not self.model.database.local:
            return

        db_host = f"{self.model.name}-db-rw.{self.model.namespace}.svc.cluster.local"
        self._inject_database_env(final_values, db_host)

    def _inject_database_env(self, final_values: dict[str, Any], db_host: str):
        """Standard ENV variable injection for DB info."""
        if "env" not in final_values:
            final_values["env"] = []
        final_values["env"].extend(
            [
                {
                    "name": "DATABASE_URL",
                    "value": f"postgresql://{self.model.name}:{self.model.name}@{db_host}:5432/{self.model.name}",
                },
                {"name": "DB_HOST", "value": db_host},
                {"name": "DB_PORT", "value": "5432"},
                {"name": "DB_NAME", "value": self.model.name},
                {"name": "DB_USER", "value": self.model.name},
                {
                    "name": "DB_PASSWORD",
                    "valueFrom": {
                        "secretKeyRef": {
                            "name": f"{self.model.name}-db-app",
                            "key": "password",
                        }
                    },
                },
            ]
        )

    def inject_init_container_for_db(
        self, final_values: dict[str, Any], wait_container: dict[str, Any]
    ):
        """Injects an initContainer to wait for the database."""
        if "controllers" in final_values:
            for ctrl_val in final_values["controllers"].values():
                if "initContainers" not in ctrl_val:
                    ctrl_val["initContainers"] = {}
                ctrl_val["initContainers"]["wait-for-database"] = wait_container

    def apply_fullname_override(self, final_values: dict[str, Any]):
        """Generic fullnameOverride for all apps to improve predictability."""
        if "fullnameOverride" not in final_values:
            final_values["fullnameOverride"] = self.model.name

    def apply_extra_env(self, final_values: dict[str, Any]):
        """Inject extra environment variables."""
        if not self.model.extra_env:
            return

        extra_env_items = [
            {"name": k, "value": v} for k, v in self.model.extra_env.items()
        ]
        self._inject_extra_env(final_values, extra_env_items)

    def _inject_extra_env(self, final_values: dict[str, Any], extra_env_items: list):
        """Standard extra_env mapping."""
        # Common pattern 1: bjw-s app-template v2/v3
        if "controllers" in final_values:
            for ctrl in final_values["controllers"].values():
                if "containers" in ctrl:
                    for cont in ctrl["containers"].values():
                        cont["env"] = self._merge_env(
                            cont.get("env", []), extra_env_items
                        )

        # Common pattern 2: standard Helm 'env' key
        if "env" in final_values or not final_values.get("controllers"):
            final_values["env"] = self._merge_env(
                final_values.get("env", []), extra_env_items
            )

    def _merge_env(self, existing_env: Any, new_items: list) -> Any:
        if isinstance(existing_env, list):
            # Deduplicate by 'name'
            env_map = {item["name"]: item for item in existing_env if "name" in item}
            for item in new_items:
                env_map[item["name"]] = item
            return list(env_map.values())
        elif isinstance(existing_env, dict):
            # Flat map update
            existing_env.update({item["name"]: item["value"] for item in new_items})
            return existing_env
        return new_items


class AppTemplateAdapter(HelmValuesAdapter):
    def _inject_storage(
        self, final_values: dict[str, Any], key: str, pvc_name: str, mount_path: str
    ):
        final_values["persistence"][key] = {
            "enabled": True,
            "type": "persistentVolumeClaim",
            "existingClaim": pvc_name,
            "globalMounts": [{"path": mount_path}],
        }


class AuthentikAdapter(HelmValuesAdapter):
    def _inject_env_from(self, final_values: dict[str, Any], env_from_item: list):
        if "global" not in final_values:
            final_values["global"] = {}
        if "envFrom" not in final_values["global"]:
            final_values["global"]["envFrom"] = []
        final_values["global"]["envFrom"].extend(env_from_item)

    def inject_config_secret(
        self, final_values: dict[str, Any], secret_ref: dict[str, Any]
    ):
        for comp in ["server", "worker"]:
            if comp not in final_values:
                final_values[comp] = {}
            if "envFrom" not in final_values[comp]:
                final_values[comp]["envFrom"] = []
            final_values[comp]["envFrom"].append(secret_ref)

    def _inject_database_env(self, final_values: dict[str, Any], db_host: str):
        # We don't put it in the base env block because authentik handles parts in "server" and "worker"
        pass

    def inject_init_container_for_db(
        self, final_values: dict[str, Any], wait_container: dict[str, Any]
    ):
        pass  # Authentik's worker/server crash loop is fine, and injecting initContainers is difficult without a custom values structure.

    def _inject_extra_env(self, final_values: dict[str, Any], extra_env_items: list):
        for comp in ["server", "worker"]:
            if comp not in final_values:
                final_values[comp] = {}
            final_values[comp]["env"] = self._merge_env(
                final_values[comp].get("env", []), extra_env_items
            )


class HomarrAdapter(HelmValuesAdapter):
    def _inject_storage(
        self, final_values: dict[str, Any], key: str, pvc_name: str, mount_path: str
    ):
        # Homarr 2.0.0 uses `.name` for both the volume name and the claimName
        final_values["persistence"][key] = {
            "enabled": True,
            "name": pvc_name,
            "mountPath": mount_path,
        }

    def _inject_extra_env(self, final_values: dict[str, Any], extra_env_items: list):
        if "env" not in final_values:
            final_values["env"] = []
        final_values["env"] = self._merge_env(final_values["env"], extra_env_items)


def get_adapter(model: AppModel) -> HelmValuesAdapter:
    chart_name = model.helm.chart
    chart_version_str = str(model.helm.version)
    app_name = model.name

    if app_name == "authentik":
        return AuthentikAdapter(model)

    is_app_template_v3 = (
        chart_name == "app-template"
        and (chart_version_str.startswith("3.") or chart_version_str.startswith("2."))
    ) or (chart_name == "navidrome" and chart_version_str.startswith("3."))

    if is_app_template_v3:
        return AppTemplateAdapter(model)

    if app_name == "homarr" or chart_name == "homarr":
        return HomarrAdapter(model)

    return HelmValuesAdapter(model)
