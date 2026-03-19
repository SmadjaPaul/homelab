import copy
from typing import Any

from shared.utils.schemas import AppModel, EnvStyle, ExposureMode
from .. import sso_presets


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
        self.apply_provisioning_config(final_values)
        self.apply_extra_env(final_values)
        self.apply_config_maps(final_values)
        self.apply_homepage_config(final_values)
        self.apply_priority_class(final_values)
        self.apply_replicas(final_values)
        self.apply_service(final_values)

        return final_values

    def apply_replicas(self, final_values: dict[str, Any]):
        """Inject replica count into Helm values."""
        if self.model.resources.replicas is not None:
            # Standard Helm charts: top-level replicas
            if "replicas" not in final_values:
                final_values["replicas"] = self.model.resources.replicas

            # bjw-s app-template v2/v3: inject under each controller
            if "controllers" in final_values:
                for ctrl in final_values["controllers"].values():
                    if isinstance(ctrl, dict):
                        ctrl.setdefault("replicas", self.model.resources.replicas)

    def apply_service(self, final_values: dict[str, Any]):
        """Inject service port into Helm values only for app-template or if explicitly needed."""
        if not self.model.network.port:
            return

        # Only auto-inject if it's an app-template or if we are sure of the structure
        is_app_template = self.model.helm and self.model.helm.chart == "app-template"

        if is_app_template:
            if "controllers" in final_values:
                # bjw-s app-template v3 style
                if "service" not in final_values:
                    final_values["service"] = {}
                if "main" not in final_values["service"]:
                    final_values["service"]["main"] = {}

                srv = final_values["service"]["main"]
                if "ports" not in srv:
                    srv["ports"] = {}
                if "http" not in srv["ports"]:
                    srv["ports"]["http"] = {}

                srv["ports"]["http"]["port"] = self.model.network.port
            else:
                # bjw-s app-template v1/v2 style
                if "service" not in final_values:
                    final_values["service"] = {}
                if "port" not in final_values["service"]:
                    final_values["service"]["port"] = self.model.network.port
        else:
            # For specialized charts, we usually don't want to blindly inject service.port
            # as it often breaks templates that expect service to be a map of service objects.
            pass

    def apply_config_maps(self, final_values: dict[str, Any]):
        """Inject additional ConfigMaps created by the registry."""
        if not self.model.config_maps:
            return

        if "persistence" not in final_values:
            final_values["persistence"] = {}

        for cm in self.model.config_maps:
            if not cm.mount_path:
                continue

            # Standard app-template v3 style mounting
            final_values["persistence"][cm.name] = {
                "enabled": True,
                "type": "configMap",
                "name": cm.name,
                "globalMounts": [{"path": cm.mount_path}],
            }

    def apply_provisioning_config(self, final_values: dict[str, Any]):
        """Inject SSO/OIDC/Header configuration based on the provisioning model."""
        if not self.model.auth.enabled and not self.model.auth.sso:
            return

        # Resolve SSO presets for all exposed apps (protected, public)
        # The domain is needed to construct issuer URLs
        domain = "smadja.dev"  # Default domain
        sso_presets.resolve_sso(self.model, domain)

    def apply_homepage_config(self, final_values: dict[str, Any]):
        """Inject Homepage discovery annotations into service/ingress values."""
        if (
            not self.model.network.hostname
            or self.model.network.mode == ExposureMode.INTERNAL
        ):
            return

        hp = self.model.homepage
        if hp and not hp.enabled:
            return

        annotations = {
            "gethomepage.dev/enabled": "true",
            "gethomepage.dev/name": self.model.name.capitalize(),
            "gethomepage.dev/description": hp.description
            if hp and hp.description
            else f"{self.model.name.capitalize()} in {self.model.namespace}",
            "gethomepage.dev/group": hp.group
            if hp and hp.group
            else self.model.category.value.capitalize(),
            "gethomepage.dev/href": f"https://{self.model.network.hostname}",
        }

        if hp and hp.weight:
            annotations["gethomepage.dev/weight"] = str(hp.weight)

        # Smart Icon detection with override
        icon_map = {
            "nextcloud": "nextcloud",
            "paperless-ngx": "paperless-ngx",
            "navidrome": "navidrome",
            "vaultwarden": "vaultwarden",
            "authentik": "authentik",
            "audiobookshelf": "audiobookshelf",
            "open-webui": "open-webui",
            "homepage": "homepage",
            "slskd": "soulseek",
        }

        icon = hp.icon if hp and hp.icon else icon_map.get(self.model.name)
        if icon:
            annotations["gethomepage.dev/icon"] = icon

        # Inject Widget if defined
        if hp and hp.widget:
            import json

            annotations["gethomepage.dev/widget"] = json.dumps(hp.widget)

        # Apply to all services/ingresses in bjw-s app-template v2/v3 style
        for block in ["service", "services", "ingress", "ingresses"]:
            if block in final_values:
                for name, config in final_values[block].items():
                    if isinstance(config, dict):
                        # For bjw-s v3, annotations are often nested under service/ingress names
                        if "annotations" not in config:
                            config["annotations"] = {}
                        config["annotations"].update(annotations)

    def apply_storage(self, final_values: dict[str, Any]):
        """Inject additional storage volumes created by the registry."""
        if not self.model.persistence.storage:
            return

        if "persistence" not in final_values:
            final_values["persistence"] = {}

        for storage in self.model.persistence.storage:
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

            self._inject_storage(
                final_values, key, pvc_name, storage.mount_path, storage
            )

    def _inject_storage(
        self,
        final_values: dict[str, Any],
        key: str,
        pvc_name: str,
        mount_path: str,
        storage=None,
    ):
        """Standard PVC injection style."""
        storage_config = {
            "enabled": True,
            "type": getattr(storage, "type", None) or "pvc",
            "existingClaim": pvc_name,
            "mountPath": mount_path,
            "accessMode": "ReadWriteOnce",
        }

        # Use storage config from apps.yaml if available
        if storage:
            if getattr(storage, "size", None):
                storage_config["size"] = storage.size
            else:
                storage_config["size"] = "1Gi"  # Default

            if getattr(storage, "storage_class", None):
                storage_config["storageClass"] = storage.storage_class

            if getattr(storage, "access", None):
                storage_config["accessMode"] = (
                    "ReadWriteMany"
                    if storage.access.value == "shared"
                    else "ReadWriteOnce"
                )
        else:
            storage_config["size"] = "1Gi"

        final_values["persistence"][key] = storage_config

    def apply_secrets(self, final_values: dict[str, Any]):
        """Automatically inject defined secrets via envFrom."""
        if not getattr(self.model, "inject_secrets", True):  # Default to True
            return

        env_from_item = []

        # 1. External Secrets (Doppler)
        if self.model.secrets:
            for req in self.model.secrets:
                env_from_item.append({"secretRef": {"name": req.name}})

        # 2. Local Auto-Secrets
        if self.model.auto_secrets:
            for name in self.model.auto_secrets.keys():
                env_from_item.append({"secretRef": {"name": name}})

        if env_from_item:
            self._inject_env_from(final_values, env_from_item)

    def _inject_env_from(self, final_values: dict[str, Any], env_from_item: list):
        """Standard envFrom injection for secrets."""

        # 1. Controllers level (bjw-s v2/v3)
        if "controllers" in final_values:
            for ctrl in final_values["controllers"].values():
                if isinstance(ctrl, dict) and "containers" in ctrl:
                    for cont in ctrl["containers"].values():
                        if isinstance(cont, dict):
                            if "envFrom" not in cont:
                                cont["envFrom"] = []
                            existing = [
                                r.get("secretRef", {}).get("name")
                                for r in cont["envFrom"]
                                if "secretRef" in r
                            ]
                            for item in env_from_item:
                                if item["secretRef"]["name"] not in existing:
                                    cont["envFrom"].append(item)
            return

        # 2. Fallback for older/simpler charts
        env_from_key = "envFrom"
        if env_from_key not in final_values:
            final_values[env_from_key] = []

        if isinstance(final_values[env_from_key], list):
            existing = [
                r.get("secretRef", {}).get("name")
                for r in final_values[env_from_key]
                if "secretRef" in r
            ]
            for item in env_from_item:
                if item["secretRef"]["name"] not in existing:
                    final_values[env_from_key].append(item)

    def inject_config_secret(
        self, final_values: dict[str, Any], secret_ref: dict[str, Any]
    ):
        """Inject unified Config Secret via envFrom."""
        self._inject_env_from(final_values, [secret_ref])

    def apply_image_pull_secrets(self, final_values: dict[str, Any]):
        """Inject imagePullSecrets for private images."""
        if not getattr(self.model, "inject_secrets", True):
            return

        secret_item = {"name": "dockerhub-secret"}

        # For bjw-s app-template v2/v3
        if "controllers" in final_values:
            for config in final_values["controllers"].values():
                if isinstance(config, dict):
                    if "pod" not in config:
                        config["pod"] = {}
                    if "imagePullSecrets" not in config["pod"]:
                        config["pod"]["imagePullSecrets"] = []

                    if secret_item not in config["pod"]["imagePullSecrets"]:
                        config["pod"]["imagePullSecrets"].append(secret_item)
        else:
            if "imagePullSecrets" not in final_values:
                final_values["imagePullSecrets"] = []

            if secret_item not in final_values["imagePullSecrets"]:
                final_values["imagePullSecrets"].append(secret_item)

    def apply_priority_class(self, final_values: dict[str, Any]):
        """Inject priorityClassName based on app tier."""
        tier = self.model.tier.value
        if tier not in ("critical", "standard"):
            return

        priority_class_name = f"homelab-{tier}"

        if "controllers" in final_values:
            for config in final_values["controllers"].values():
                if isinstance(config, dict):
                    if "pod" not in config:
                        config["pod"] = {}
                    config["pod"].setdefault("priorityClassName", priority_class_name)
        else:
            final_values.setdefault("priorityClassName", priority_class_name)

    def apply_database(self, final_values: dict[str, Any]):
        """Inject local database connection info."""
        if (
            not self.model.persistence.database
            or not self.model.persistence.database.local
        ):
            return

        db_host = "homelab-db-rw.cnpg-system.svc.cluster.local"
        self._inject_database_env(final_values, db_host)

    def _inject_database_env(self, final_values: dict[str, Any], db_host: str):
        """Standard ENV variable injection for DB info."""
        prefix = (
            self.model.helm.db_env_prefix if self.model.helm else None
        ) or "POSTGRES"

        if prefix == "PAPERLESS_DB":
            db_env = [
                {"name": "PAPERLESS_DBHOST", "value": db_host},
                {"name": "PAPERLESS_DBPORT", "value": "5432"},
                {"name": "PAPERLESS_DBNAME", "value": self.model.name},
                {"name": "PAPERLESS_DBUSER", "value": self.model.name},
                {"name": "PAPERLESS_DBENGINE", "value": "postgresql"},
                {
                    "name": "PAPERLESS_DBPASS",
                    "valueFrom": {
                        "secretKeyRef": {
                            "name": f"{self.model.name}-db-app",
                            "key": "password",
                        }
                    },
                },
            ]
        else:
            db_env = [
                {"name": f"{prefix}_HOST", "value": db_host},
                {"name": f"{prefix}_PORT", "value": "5432"},
                {"name": f"{prefix}_DB", "value": self.model.name},
                {"name": f"{prefix}_USER", "value": self.model.name},
                {
                    "name": f"{prefix}_PASSWORD",
                    "valueFrom": {
                        "secretKeyRef": {
                            "name": f"{self.model.name}-db-app",
                            "key": "password",
                        }
                    },
                },
            ]

            if prefix == "POSTGRES":
                db_env.extend(
                    [
                        {"name": "DB_HOSTNAME", "value": db_host},
                        {"name": "DB_HOST", "value": db_host},
                        {"name": "DATABASE_HOST", "value": db_host},
                        {"name": "DB_DATABASE", "value": self.model.name},
                        {"name": "DB_USERNAME", "value": self.model.name},
                        {
                            "name": "DB_PASSWORD",
                            "valueFrom": {
                                "secretKeyRef": {
                                    "name": f"{self.model.name}-db-app",
                                    "key": "password",
                                }
                            },
                        },
                        {
                            "name": "IMMICH_DATABASE_PASSWORD",
                            "valueFrom": {
                                "secretKeyRef": {
                                    "name": f"{self.model.name}-db-app",
                                    "key": "password",
                                }
                            },
                        },
                    ]
                )

            if prefix == "POSTGRES":
                db_env.append(
                    {
                        "name": "DATABASE_URL",
                        "valueFrom": {
                            "secretKeyRef": {
                                "name": f"{self.model.name}-db-app",
                                "key": "uri",
                            }
                        },
                    }
                )

        self._inject_extra_env(final_values, db_env)

    def inject_init_container_for_db(
        self, final_values: dict[str, Any], wait_container: dict[str, Any]
    ):
        """Injects an initContainer to wait for the database."""
        # Ensure image is in the correct format (dictionary) for newer charts
        wait_container_v3 = copy.deepcopy(wait_container)
        image_val = wait_container_v3.get("image", "alpine:3.21")

        if isinstance(image_val, str):
            if ":" in image_val:
                repo, tag = image_val.split(":", 1)
                wait_container_v3["image"] = {"repository": repo, "tag": tag}
            else:
                wait_container_v3["image"] = {"repository": image_val, "tag": "latest"}

        if "controllers" in final_values:
            for ctrl_val in final_values["controllers"].values():
                if isinstance(ctrl_val, dict):
                    if "initContainers" not in ctrl_val:
                        ctrl_val["initContainers"] = {}
                    # Use v3-compatible name/format for controllers
                    wait_name = wait_container_v3.get("name", "wait-for-database")
                    ctrl_val["initContainers"][wait_name] = copy.deepcopy(
                        wait_container_v3
                    )
                    # Common chart v3/v4 doesn't want 'name' inside the initContainer dict when keyed by name
                    ctrl_val["initContainers"][wait_name].pop("name", None)
        else:
            # Fallback for old style charts or intermediate common charts
            if "initContainers" not in final_values:
                # Most modern specialized charts (using bjw-s common) expect a map
                final_values["initContainers"] = {}

            if isinstance(final_values["initContainers"], dict):
                wait_name = wait_container.get("name", "wait-for-database")
                final_values["initContainers"][wait_name] = wait_container
            elif isinstance(final_values["initContainers"], list):
                # Check if already exists in list
                existing_names = [
                    c.get("name")
                    for c in final_values["initContainers"]
                    if isinstance(c, dict)
                ]
                if wait_container["name"] not in existing_names:
                    final_values["initContainers"].append(wait_container)

    def apply_fullname_override(self, final_values: dict[str, Any]):
        """Generic fullnameOverride for all apps - only if not already set."""
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
        """Standard extra_env mapping respecting chart hints."""

        # 1. Controllers level (bjw-s app-template v2/v3)
        env_key = (self.model.helm.env_key if self.model.helm else None) or "env"
        if "controllers" in final_values:
            for item in final_values["controllers"].values():
                if isinstance(item, dict) and "containers" in item:
                    for container in item["containers"].values():
                        if isinstance(container, dict):
                            container[env_key] = self._merge_env(
                                container.get(env_key, []), extra_env_items
                            )
            return

        # 2. Top-level key
        env_key = (self.model.helm.env_key if self.model.helm else None) or "env"
        current_env = final_values.get(env_key)
        env_style = self.model.helm.env_style if self.model.helm else EnvStyle.LIST
        is_map_style = env_style == EnvStyle.MAP or isinstance(current_env, dict)

        if is_map_style:
            if env_key not in final_values:
                final_values[env_key] = {}
            final_values[env_key] = self._merge_env(
                final_values[env_key], extra_env_items
            )
        else:
            if env_key not in final_values:
                final_values[env_key] = []
            final_values[env_key] = self._merge_env(
                final_values[env_key], extra_env_items
            )

        # 3. Heuristic for specialized charts (immich, authentik, etc.)
        # If they have common component keys, inject there too
        common_components = [
            "server",
            "worker",
            "machine-learning",
            "microservices",
            "api",
        ]
        for comp in common_components:
            if comp in final_values and isinstance(final_values[comp], dict):
                # Specialized charts often have their own 'env' per component
                comp_env_key = "env"  # Usually 'env' for these
                comp_env = final_values[comp].get(comp_env_key, {})
                final_values[comp][comp_env_key] = self._merge_env(
                    comp_env, extra_env_items
                )

    def _merge_env(self, existing_env: Any, new_items: list) -> Any:
        if isinstance(existing_env, list):
            env_map = {item["name"]: item for item in existing_env if "name" in item}
            for item in new_items:
                env_map[item["name"]] = item
            return list(env_map.values())
        elif isinstance(existing_env, dict):
            # Create a shallow copy to stay safe
            env_dict = existing_env.copy()
            for item in new_items:
                name = item["name"]
                if "value" in item:
                    env_dict[name] = item["value"]
                elif "valueFrom" in item:
                    env_dict[name] = item["valueFrom"]
                else:
                    # Catch-all for other fields
                    env_dict[name] = {k: v for k, v in item.items() if k != "name"}
            return env_dict
        return new_items


class AppTemplateAdapter(HelmValuesAdapter):
    def _inject_storage(
        self,
        final_values: dict[str, Any],
        key: str,
        pvc_name: str,
        mount_path: str,
        storage=None,
    ):
        storage_config = {
            "enabled": True,
            "type": getattr(storage, "type", None) or "persistentVolumeClaim",
            "existingClaim": pvc_name,
            "globalMounts": [{"path": mount_path}],
        }
        if "persistence" not in final_values:
            final_values["persistence"] = {}
        final_values["persistence"][key] = storage_config

    def inject_init_container_for_db(
        self, final_values: dict[str, Any], wait_container: dict[str, Any]
    ):
        """Override for bjw-s app-template v3 schema - now handled by base class."""
        return super().inject_init_container_for_db(final_values, wait_container)


class AuthentikAdapter(HelmValuesAdapter):
    """Special adapter for Authentik."""

    def apply_replicas(self, final_values: dict[str, Any]):
        if self.model.resources.replicas is not None:
            for component in ("server", "worker"):
                if component not in final_values:
                    final_values[component] = {}
                final_values[component].setdefault(
                    "replicas", self.model.resources.replicas
                )

    def apply_service(self, final_values: dict[str, Any]):
        """Authentik chart has its own internal service mapping, skip generic injection."""
        pass

    def apply_priority_class(self, final_values: dict[str, Any]):
        tier = self.model.tier.value
        if tier not in ("critical", "standard"):
            return
        priority_class_name = f"homelab-{tier}"
        for component in ("server", "worker"):
            if component not in final_values:
                final_values[component] = {}
            final_values[component].setdefault("priorityClassName", priority_class_name)

    def _inject_extra_env(self, final_values: dict[str, Any], extra_env_items: list):
        if "global" not in final_values:
            final_values["global"] = {}
        if "env" not in final_values["global"]:
            final_values["global"]["env"] = []

        final_values["global"]["env"] = self._merge_env(
            final_values["global"]["env"], extra_env_items
        )

        if "authentik" not in final_values:
            final_values["authentik"] = {}
        if "env" not in final_values["authentik"]:
            final_values["authentik"]["env"] = []

        final_values["authentik"]["env"] = self._merge_env(
            final_values["authentik"]["env"], extra_env_items
        )

    def _inject_env_from(self, final_values: dict[str, Any], env_from_item: list):
        if "global" not in final_values:
            final_values["global"] = {}
        if "envFrom" not in final_values["global"]:
            final_values["global"]["envFrom"] = []

        for item in env_from_item:
            existing = [
                r.get("secretRef", {}).get("name")
                for r in final_values["global"]["envFrom"]
                if "secretRef" in r
            ]
            if item["secretRef"]["name"] not in existing:
                final_values["global"]["envFrom"].append(item)

        if "authentik" not in final_values:
            final_values["authentik"] = {}
        if "envFrom" not in final_values["authentik"]:
            final_values["authentik"]["envFrom"] = []

        for item in env_from_item:
            existing = [
                r.get("secretRef", {}).get("name")
                for r in final_values["authentik"]["envFrom"]
                if "secretRef" in r
            ]
            if item["secretRef"]["name"] not in existing:
                final_values["authentik"]["envFrom"].append(item)

    def _inject_database_env(self, final_values: dict[str, Any], db_host: str):
        if "authentik" not in final_values:
            final_values["authentik"] = {}
        if "postgresql" not in final_values["authentik"]:
            final_values["authentik"]["postgresql"] = {}

        final_values["authentik"]["postgresql"].update(
            {
                "host": db_host,
                "user": self.model.name,
                "name": self.model.name,
                "port": 5432,
                "password": {
                    "valueFrom": {
                        "secretKeyRef": {
                            "name": f"{self.model.name}-db-app",
                            "key": "password",
                        }
                    }
                },
            }
        )

        if "redis" not in final_values["authentik"]:
            final_values["authentik"]["redis"] = {}
        final_values["authentik"]["redis"].update(
            {
                "host": "redis.storage.svc.cluster.local",
                "port": 6379,
            }
        )
        final_values["redis"] = {"enabled": False}

        db_env = [
            {"name": "AUTHENTIK_POSTGRESQL__HOST", "value": db_host},
            {"name": "AUTHENTIK_POSTGRESQL__USER", "value": self.model.name},
            {"name": "AUTHENTIK_POSTGRESQL__NAME", "value": self.model.name},
            {
                "name": "AUTHENTIK_POSTGRESQL__PASSWORD",
                "valueFrom": {
                    "secretKeyRef": {
                        "name": f"{self.model.name}-db-app",
                        "key": "password",
                    }
                },
            },
        ]
        self._inject_extra_env(final_values, db_env)
        final_values["postgresql"] = {"enabled": False}

    def inject_init_container_for_db(
        self, final_values: dict[str, Any], wait_container: dict[str, Any]
    ):
        """Authentik deprecates top-level initContainers, inject into server and worker."""
        for component in ("server", "worker"):
            if component not in final_values:
                final_values[component] = {}
            if "initContainers" not in final_values[component]:
                final_values[component]["initContainers"] = []

            if isinstance(final_values[component]["initContainers"], list):
                existing_names = [
                    c.get("name")
                    for c in final_values[component]["initContainers"]
                    if isinstance(c, dict)
                ]
                if wait_container["name"] not in existing_names:
                    final_values[component]["initContainers"].append(wait_container)


def get_adapter(model: AppModel) -> HelmValuesAdapter:
    chart_name = model.helm.chart if model.helm else None
    app_name = model.name

    if app_name == "authentik":
        return AuthentikAdapter(model)

    if chart_name == "app-template":
        return AppTemplateAdapter(model)

    return HelmValuesAdapter(model)
