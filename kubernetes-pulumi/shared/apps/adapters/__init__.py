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
        self.apply_config_maps(final_values)
        self.apply_provisioning_config(final_values)
        self.apply_homepage_config(final_values)

        return final_values

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
        if not self.model.auth:
            return

        # 1. Standard Proxy Headers (Gate Layer)
        # Injected for all protected apps to enable SSO identification
        if self.model.mode.value == "protected":
            proxy_headers = [
                {"name": "HTTP_X_AUTHENTIK_USERNAME", "value": "X-Authentik-Username"},
                {"name": "HTTP_X_AUTHENTIK_GROUPS", "value": "X-Authentik-Groups"},
                {"name": "HTTP_X_AUTHENTIK_EMAIL", "value": "X-Authentik-Email"},
                {"name": "HTTP_X_AUTHENTIK_NAME", "value": "X-Authentik-Name"},
                {"name": "HTTP_X_AUTHENTIK_UID", "value": "X-Authentik-Uid"},
            ]
            self._inject_extra_env(final_values, proxy_headers)

        # 2. App-Level Provisioning (Identity Layer)
        prov = self.model.provisioning
        if not prov or prov.method.value == "none":
            return

        domain = "smadja.dev"
        if prov.method.value == "oidc":
            client_id = prov.client_id or f"{self.model.name}-client"
            # OIDC sidecar slug convention: {name}-oidc for protected apps
            oidc_slug = (
                self.model.name
                if self.model.mode.value == "public"
                else f"{self.model.name}-oidc"
            )

            oidc_env = {
                "opencloud": [
                    (
                        "OCIS_OIDC_ISSUER",
                        f"https://auth.{domain}/application/o/{oidc_slug}/",
                    ),
                    (
                        "OC_OIDC_ISSUER",
                        f"https://auth.{domain}/application/o/{oidc_slug}/",
                    ),
                    ("PROXY_AUTOPROVISION_ACCOUNTS", "true"),
                    ("PROXY_OIDC_REWRITE_WELLKNOWN", "true"),
                    ("WEB_OIDC_CLIENT_ID", client_id),
                    ("PROXY_AUTOPROVISION_CLAIM_USERNAME", "preferred_username"),
                    ("PROXY_AUTOPROVISION_CLAIM_EMAIL", "email"),
                    ("PROXY_AUTOPROVISION_CLAIM_DISPLAYNAME", "name"),
                    ("OC_EXCLUDE_RUN_SERVICES", "idp"),
                ],
                "open-webui": [
                    ("ENABLE_OAUTH_SIGNUP", "true"),
                    ("OAUTH_MERGE_ACCOUNTS_BY_EMAIL", "true"),
                    ("OAUTH_PROVIDER_NAME", "Authentik"),
                    ("OAUTH_CLIENT_ID", client_id),
                    (
                        "OPENID_PROVIDER_URL",
                        f"https://auth.{domain}/application/o/{oidc_slug}/.well-known/openid-configuration",
                    ),
                    ("OAUTH_SCOPES", "openid profile email"),
                    ("WEBUI_URL", f"https://{self.model.hostname}"),
                ],
                "vaultwarden": [
                    ("SSO_ENABLED", "true"),
                    (
                        "SSO_AUTHORITY",
                        f"https://auth.{domain}/application/o/{oidc_slug}/",
                    ),
                    ("SSO_CLIENT_ID", client_id),
                    ("SSO_SIGNUPS_MATCH_EMAIL", "true"),
                ],
            }
            env_list = [
                {"name": k, "value": v} for k, v in oidc_env.get(self.model.name, [])
            ]
            self._inject_extra_env(final_values, env_list)

        elif prov.method.value == "header":
            header_env = {
                "paperless-ngx": [
                    ("PAPERLESS_ENABLE_HTTP_REMOTE_USER", "true"),
                    ("PAPERLESS_HTTP_REMOTE_USER_HEADER", "HTTP_X_AUTHENTIK_USERNAME"),
                    ("PAPERLESS_HTTP_REMOTE_USER_AUTH_ALLOW_SIGNUPS", "true"),
                ],
                "navidrome": [
                    ("ND_REVERSEPROXYUSERHEADER", "X-Authentik-Username"),
                    ("ND_REVERSEPROXYWHITELIST", "0.0.0.0/0"),
                ],
                "slskd": [("SLSKD_REMOTE_USER_HEADER", "HTTP_X_AUTHENTIK_USERNAME")],
            }
            env_list = [
                {"name": k, "value": v} for k, v in header_env.get(self.model.name, [])
            ]
            self._inject_extra_env(final_values, env_list)

    def apply_homepage_config(self, final_values: dict[str, Any]):
        """Inject Homepage discovery annotations into service/ingress values."""
        if not self.model.hostname or self.model.mode.value == "internal":
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
            "gethomepage.dev/href": f"https://{self.model.hostname}",
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
            "type": "pvc",
            "existingClaim": pvc_name,
            "mountPath": mount_path,
            "accessMode": "ReadWriteOnce",
        }

        # Use storage config from apps.yaml if available
        if storage:
            if getattr(storage, "size", None):
                storage_config["size"] = storage.size
            else:
                storage_config["size"] = "1Gi"  # Default, not 50Gi

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
        if not self.model.inject_secrets:
            return

        import pulumi

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
            pulumi.log.info(
                f"    [Adapter] Injecting {len(env_from_item)} secrets via envFrom for {self.model.name}"
            )
            self._inject_env_from(final_values, env_from_item)

    def _inject_env_from(self, final_values: dict[str, Any], env_from_item: list):
        """Standard envFrom injection for secrets."""

        # 1. Controllers level (bjw-s v2/v3) - PREFERRED for modern charts
        if "controllers" in final_values:
            for ctrl in final_values["controllers"].values():
                if isinstance(ctrl, dict) and "containers" in ctrl:
                    for cont in ctrl["containers"].values():
                        if isinstance(cont, dict):
                            if "envFrom" not in cont:
                                cont["envFrom"] = []
                            # Deduplicate
                            existing = [
                                r.get("secretRef", {}).get("name")
                                for r in cont["envFrom"]
                                if "secretRef" in r
                            ]
                            for item in env_from_item:
                                if item["secretRef"]["name"] not in existing:
                                    cont["envFrom"].append(item)
            return  # Injection handled for bjw-s

        # 2. Fallback for older/simpler charts (Top level)
        if "envFrom" not in final_values:
            final_values["envFrom"] = []

        if isinstance(final_values["envFrom"], list):
            existing = [
                r.get("secretRef", {}).get("name")
                for r in final_values["envFrom"]
                if "secretRef" in r
            ]
            for item in env_from_item:
                if item["secretRef"]["name"] not in existing:
                    final_values["envFrom"].append(item)
        elif isinstance(final_values["envFrom"], dict):
            # Some charts use a dict for envFrom? (rarely)
            pass

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

        db_host = "homelab-db-rw.cnpg-system.svc.cluster.local"
        self._inject_database_env(final_values, db_host)

    def _inject_database_env(self, final_values: dict[str, Any], db_host: str):
        """Standard ENV variable injection for DB info."""
        if "env" not in final_values:
            final_values["env"] = []

        final_values["env"] = self._merge_env(
            final_values["env"],
            [
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
            ],
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
        self,
        final_values: dict[str, Any],
        key: str,
        pvc_name: str,
        mount_path: str,
        storage=None,
    ):
        storage_config = {
            "enabled": True,
            "type": "persistentVolumeClaim",
            "existingClaim": pvc_name,
            "globalMounts": [{"path": mount_path}],
        }
        # For existingClaim, app-template v3 forbids storageClass/size at this level
        final_values["persistence"][key] = storage_config


class AuthentikAdapter(HelmValuesAdapter):
    def apply_storage(self, final_values: dict[str, Any]):
        """Authentik uses global.volumes and global.volumeMounts for shared storage."""
        if not self.model.storage:
            return

        if "global" not in final_values:
            final_values["global"] = {}
        if "volumes" not in final_values["global"]:
            final_values["global"]["volumes"] = []
        if "volumeMounts" not in final_values["global"]:
            final_values["global"]["volumeMounts"] = []

        for storage in self.model.storage:
            pvc_name = (
                storage.existing_claim
                if hasattr(storage, "existing_claim") and storage.existing_claim
                else f"{self.model.name}-{storage.name}"
            )

            # Add volume
            final_values["global"]["volumes"].append(
                {"name": storage.name, "persistentVolumeClaim": {"claimName": pvc_name}}
            )

            # Add volume mount
            final_values["global"]["volumeMounts"].append(
                {"name": storage.name, "mountPath": storage.mount_path}
            )

    def _inject_database_env(self, final_values: dict[str, Any], db_host: str):
        # Authentik chart expects postgresql settings under 'authentik' key
        if "authentik" not in final_values:
            final_values["authentik"] = {}
        if "postgresql" not in final_values["authentik"]:
            final_values["authentik"]["postgresql"] = {}

        # Also need the top-level postgresql.enabled=false for the subchart
        if "postgresql" not in final_values:
            final_values["postgresql"] = {}
        final_values["postgresql"]["enabled"] = False

        # Enforce external DB settings in both places just to be sure
        db_config = {
            "host": db_host,
            "name": self.model.name,
            "user": self.model.name,
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
        final_values["authentik"]["postgresql"].update(db_config)

        # Also inject environment variables for components
        extra_env = [
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
        self._inject_extra_env(final_values, extra_env)

    def _inject_extra_env(self, final_values: dict[str, Any], extra_env_items: list):
        # Authentik uses authentik.env for global and component.env for specific
        if "authentik" not in final_values:
            final_values["authentik"] = {}
        if "env" not in final_values["authentik"]:
            final_values["authentik"]["env"] = []

        final_values["authentik"]["env"] = self._merge_env(
            final_values["authentik"]["env"], extra_env_items
        )

        # Also keep per-component for safety/overrides
        for comp in ["server", "worker"]:
            if comp not in final_values:
                final_values[comp] = {}
            if "env" not in final_values[comp]:
                final_values[comp]["env"] = []
            final_values[comp]["env"] = self._merge_env(
                final_values[comp].get("env", []), extra_env_items
            )

    def _inject_env_from(self, final_values: dict[str, Any], env_from_item: list):
        """Authentik uses authentik.envFrom."""
        if "authentik" not in final_values:
            final_values["authentik"] = {}
        if "envFrom" not in final_values["authentik"]:
            final_values["authentik"]["envFrom"] = []

        existing = [
            r.get("secretRef", {}).get("name")
            for r in final_values["authentik"]["envFrom"]
            if "secretRef" in r
        ]
        for item in env_from_item:
            if item["secretRef"]["name"] not in existing:
                final_values["authentik"]["envFrom"].append(item)


class VaultwardenAdapter(HelmValuesAdapter):
    def _inject_database_env(self, final_values: dict[str, Any], db_host: str):
        # Gabe565's vaultwarden chart uses env as a list or map
        # We also need to set DATABASE_URL correctly for vaultwarden
        db_password_ref = {
            "valueFrom": {
                "secretKeyRef": {
                    "name": f"{self.model.name}-db-app",
                    "key": "password",
                }
            }
        }

        # Vaultwarden doesn't support secret interpolation in the connection string directly via env vars easily
        # so we rely on DB_HOST, DB_USER, DB_PASSWORD which it ALSO supports.
        extra_env = [
            {"name": "DB_TYPE", "value": "postgresql"},
            {"name": "DB_HOST", "value": db_host},
            {"name": "DB_PORT", "value": "5432"},
            {"name": "DB_NAME", "value": self.model.name},
            {"name": "DB_USER", "value": self.model.name},
            {"name": "DB_PASSWORD", **db_password_ref},
        ]

        self._inject_extra_env(final_values, extra_env)


class PaperlessAdapter(HelmValuesAdapter):
    def _inject_database_env(self, final_values: dict[str, Any], db_host: str):
        # gabe565/paperless-ngx chart uses direct environment variables for external databases
        if "env" not in final_values:
            final_values["env"] = {}

        final_values["env"].update(
            {
                "PAPERLESS_DBHOST": db_host,
                "PAPERLESS_DBPORT": "5432",
                "PAPERLESS_DBNAME": self.model.name,
                "PAPERLESS_DBUSER": self.model.name,
                "PAPERLESS_DBPASS": {
                    "valueFrom": {
                        "secretKeyRef": {
                            "name": f"{self.model.name}-db-app",
                            "key": "password",
                        }
                    }
                },
                "PAPERLESS_DBENGINE": "postgresql",
            }
        )


class DifyAdapter(HelmValuesAdapter):
    def _inject_database_env(self, final_values: dict[str, Any], db_host: str):
        # Dify has one of the most complex structures
        final_values["postgresql"] = {"enabled": False}
        final_values["db"] = {
            "type": "postgresql",
            "host": db_host,
            "port": 5432,
            "database": self.model.name,
            "user": self.model.name,
            "password": "{{ .Values.db.passwordSecretKey }}",
            "existingSecret": f"{self.model.name}-db-app",
            "passwordSecretKey": "password",
        }


class AIGatewayAdapter(HelmValuesAdapter):
    def get_final_values(self) -> dict[str, Any]:
        # AIGateway transformation for Envoy AI Gateway CRDs if needed
        return super().get_final_values()


class OpenWebUIAdapter(HelmValuesAdapter):
    """Adapter for open-webui chart which has its own persistence format."""

    def _inject_storage(
        self,
        final_values: dict[str, Any],
        key: str,
        pvc_name: str,
        mount_path: str,
        storage=None,
    ):
        """Open-webui uses a specific persistence block at root level and for pipelines."""
        if key == "open-webui" or key == "data" or "pipelines" not in key:
            # Map the primary storage to the 'persistence' block
            if "persistence" not in final_values:
                final_values["persistence"] = {}

            final_values["persistence"].update(
                {
                    "enabled": True,
                    "existingClaim": pvc_name,
                }
            )

            if storage:
                if getattr(storage, "size", None):
                    final_values["persistence"]["size"] = storage.size
                if getattr(storage, "storage_class", None):
                    final_values["persistence"]["storageClass"] = storage.storage_class

        elif "pipelines" in key:
            # Map the pipelines storage to the 'pipelines.persistence' block
            if "pipelines" not in final_values:
                final_values["pipelines"] = {}
            if "persistence" not in final_values["pipelines"]:
                final_values["pipelines"]["persistence"] = {}

            final_values["pipelines"]["persistence"].update(
                {
                    "enabled": True,
                    "existingClaim": pvc_name,
                }
            )

            if storage:
                if getattr(storage, "size", None):
                    final_values["pipelines"]["persistence"]["size"] = storage.size
                if getattr(storage, "storage_class", None):
                    final_values["pipelines"]["persistence"]["storageClass"] = (
                        storage.storage_class
                    )

    def _inject_extra_env(self, final_values: dict[str, Any], extra_env_items: list):
        """Open-webui uses 'extraEnvVars' at the root level."""
        if "extraEnvVars" not in final_values:
            final_values["extraEnvVars"] = []

        final_values["extraEnvVars"] = self._merge_env(
            final_values.get("extraEnvVars", []), extra_env_items
        )

    def _inject_extra_env(self, final_values: dict[str, Any], extra_env_items: list):
        """Open-webui uses 'extraEnvVars' at the root level."""
        if "extraEnvVars" not in final_values:
            final_values["extraEnvVars"] = []

        final_values["extraEnvVars"] = self._merge_env(
            final_values.get("extraEnvVars", []), extra_env_items
        )


class OpenCloudAdapter(AppTemplateAdapter):
    """Adapter for OpenCloud (oCIS fork) which has slightly different vault key requirements."""

    def _inject_extra_env(self, final_values: dict[str, Any], extra_env_items: list):
        """OpenCloud often expects specific values to be passed through the 'env' list."""
        super()._inject_extra_env(final_values, extra_env_items)


def get_adapter(model: AppModel) -> HelmValuesAdapter:
    chart_name = model.helm.chart
    chart_version_str = str(model.helm.version)
    app_name = model.name

    if app_name == "authentik":
        return AuthentikAdapter(model)

    if app_name == "open-webui" or chart_name == "open-webui":
        return OpenWebUIAdapter(model)

    if app_name == "opencloud" or chart_name == "opencloud":
        return OpenCloudAdapter(model)

    is_app_template_v3 = (
        chart_name == "app-template"
        and (chart_version_str.startswith("3.") or chart_version_str.startswith("2."))
    ) or (app_name in ["navidrome", "slskd"] and chart_version_str.startswith("3."))

    if is_app_template_v3:
        if app_name == "opencloud":
            return OpenCloudAdapter(model)
        return AppTemplateAdapter(model)

    if (
        app_name == "paperless"
        or app_name == "paperless-ngx"
        or chart_name == "paperless-ngx"
    ):
        return PaperlessAdapter(model)

    if app_name == "vaultwarden" or chart_name == "vaultwarden":
        return VaultwardenAdapter(model)

    if app_name == "dify" or chart_name == "dify":
        return DifyAdapter(model)

    if app_name == "envoy-ai-gateway" or chart_name == "envoy-ai-gateway":
        return AIGatewayAdapter(model)

    return HelmValuesAdapter(model)
