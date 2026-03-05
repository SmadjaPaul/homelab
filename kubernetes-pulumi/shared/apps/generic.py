import pulumi
import pulumi_kubernetes as k8s
import pulumi_kubernetes.helm.v3 as helm
import copy
from typing import Optional, Any
from shared.apps.base import BaseApp
from shared.utils.schemas import AppModel


class GenericHelmApp(BaseApp):
    def __init__(self, model: AppModel):
        super().__init__(model)

    def get_final_values(self) -> dict[str, Any]:
        """Provides the final dictionary of Helm values."""
        # Use deepcopy to avoid mutating the original model's values during processing
        final_values = (
            copy.deepcopy(self._model.helm.values)
            if self._model.helm and self._model.helm.values
            else {}
        )
        app_name = self._model.name
        chart_name = self._model.helm.chart

        # Merge values
        # The initial deepcopy handles the base values, no need for .copy() here.

        # Mount additional storage volumes created by registry
        if self._model.storage:
            if "persistence" not in final_values:
                final_values["persistence"] = {}

            for storage in self._model.storage:
                key = storage.name
                pvc_name = (
                    storage.existing_claim
                    if hasattr(storage, "existing_claim") and storage.existing_claim
                    else f"{self._model.name}-{storage.name}"
                )

                # 1. Skip if already defined in manually provided values
                if key in final_values.get("persistence", {}):
                    continue

                # 2. Check if a similar key (exact match or typical suffix) is already defined
                found_similar = False
                for existing_key in final_values.get("persistence", {}).keys():
                    if (
                        key.lower() == existing_key.lower()
                        or existing_key.lower().endswith(key.lower())
                    ):
                        found_similar = True
                        break
                if found_similar:
                    continue

                # Smart mapping for BJW-S / Common app-template
                chart_version_str = str(self._model.helm.version)
                is_v3 = (
                    chart_name == "app-template"
                    and (
                        chart_version_str.startswith("3.")
                        or chart_version_str.startswith("2.")
                    )
                ) or (chart_name == "navidrome" and chart_version_str.startswith("3."))

                if is_v3:
                    final_values["persistence"][key] = {
                        "enabled": True,
                        "type": "persistentVolumeClaim",
                        "existingClaim": pvc_name,
                        "globalMounts": [{"path": storage.mount_path}],
                    }
                elif app_name == "homarr" or chart_name == "homarr":
                    # Homarr 2.0.0 uses `.name` for both the volume name and the claimName
                    final_values["persistence"][key] = {
                        "enabled": True,
                        "name": pvc_name,
                        "mountPath": storage.mount_path,
                    }
                else:
                    final_values["persistence"][key] = {
                        "enabled": True,
                        "type": "pvc",
                        "existingClaim": pvc_name,
                        "mountPath": storage.mount_path,
                    }

        # Automatically inject defined secrets via envFrom
        if self._model.secrets and self._model.inject_secrets:
            env_from_item = [
                {"secretRef": {"name": req.name}} for req in self._model.secrets
            ]

            # Authentik 2024.10+ uses global.envFrom
            if app_name == "authentik":
                if "global" not in final_values:
                    final_values["global"] = {}
                if "envFrom" not in final_values["global"]:
                    final_values["global"]["envFrom"] = []
                final_values["global"]["envFrom"].extend(env_from_item)
            else:
                if "global" not in final_values:
                    final_values["global"] = {}
                if "envFrom" not in final_values["global"]:
                    final_values["global"]["envFrom"] = []
                final_values["global"]["envFrom"].extend(env_from_item)

            if "controllers" in final_values:
                for ctrl_name, ctrl_val in final_values["controllers"].items():
                    if "containers" in ctrl_val:
                        for cont_name, cont_val in ctrl_val["containers"].items():
                            if "envFrom" not in cont_val:
                                cont_val["envFrom"] = []
                            cont_val["envFrom"].extend(env_from_item)

        # Inject imagePullSecrets for private images, but skip if inject_secrets is false
        if self._model.inject_secrets and "imagePullSecrets" not in final_values:
            final_values["imagePullSecrets"] = [{"name": "dockerhub-secret"}]

        # Inject local database connection info
        if self._model.database and self._model.database.local:
            db_host = (
                f"{self._model.name}-db-rw.{self._model.namespace}.svc.cluster.local"
            )

            if app_name != "authentik":
                if "env" not in final_values:
                    final_values["env"] = []
                final_values["env"].extend(
                    [
                        {
                            "name": "DATABASE_URL",
                            "value": f"postgresql://{self._model.name}:{self._model.name}@{db_host}:5432/{self._model.name}",
                        },
                        {"name": "DB_HOST", "value": db_host},
                        {"name": "DB_PORT", "value": "5432"},
                        {"name": "DB_NAME", "value": self._model.name},
                        {"name": "DB_USER", "value": self._model.name},
                        {
                            "name": "DB_PASSWORD",
                            "valueFrom": {
                                "secretKeyRef": {
                                    "name": f"{self._model.name}-db-app",
                                    "key": "password",
                                }
                            },
                        },
                    ]
                )

        # Generic fullnameOverride for all apps to improve predictability
        if "fullnameOverride" not in final_values:
            final_values["fullnameOverride"] = self._model.name

        # Inject extra environment variables
        if self._model.extra_env:
            if app_name == "authentik":
                # Authentik prefers env in server/worker sub-keys
                extra_env_items = [
                    {"name": k, "value": v} for k, v in self._model.extra_env.items()
                ]
                for comp in ["server", "worker"]:
                    if comp not in final_values:
                        final_values[comp] = {}
                    if "env" not in final_values[comp]:
                        final_values[comp]["env"] = []
                    final_values[comp]["env"].extend(extra_env_items)
            elif app_name == "homarr" or chart_name == "homarr":
                # Homarr uses a MAP for env
                if "env" not in final_values:
                    final_values["env"] = {}
                final_values["env"].update(self._model.extra_env)
            else:
                extra_env_items = [
                    {"name": k, "value": v} for k, v in self._model.extra_env.items()
                ]
                # Common pattern 1: bjw-s app-template v2/v3
                if "controllers" in final_values:
                    for ctrl in final_values["controllers"].values():
                        if "containers" in ctrl:
                            for cont in ctrl["containers"].values():
                                if "env" not in cont:
                                    cont["env"] = []
                                cont["env"].extend(extra_env_items)

                # Common pattern 2: standard Helm 'env' key
                if "env" not in final_values:
                    final_values["env"] = []
                if isinstance(final_values["env"], list):
                    final_values["env"].extend(extra_env_items)
                elif isinstance(final_values["env"], dict):
                    final_values["env"].update(self._model.extra_env)

        return final_values

    def deploy_components(
        self,
        provider: k8s.Provider,
        config: dict[str, Any],
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> dict[str, Any]:
        chart_name = self._model.helm.chart
        chart_version = self._model.helm.version
        repo_url = self._model.helm.repo

        final_values = self.get_final_values()

        is_oci = repo_url and repo_url.startswith("oci://")

        # For OCI, we often need the full path in the chart field
        actual_chart = f"{repo_url}/{chart_name}" if is_oci else chart_name

        # Standard deployment logic

        # Standard deployment logic

        # Create the unified configuration secret
        config_secret_data = {}

        # 1. Process Auto-Secrets (dynamically generated local passwords)
        auto_secret_resources = []
        if self._model.auto_secrets:
            import pulumi_random as random

            for secret_name, secret_dict in self._model.auto_secrets.items():
                secret_data = {}
                for secret_key, length in secret_dict.items():
                    # Detection for hex keys (like Homarr's 64-char encryption key)
                    # Case-insensitive check for _KEY or -KEY
                    is_hex_key = (
                        secret_key.upper().endswith("_KEY")
                        or secret_key.upper().endswith("-KEY")
                    ) and length == 64

                    password = random.RandomPassword(
                        f"{self._model.name}-auto-secret-{secret_name}-{secret_key.lower().replace('_', '-')}-v4",
                        length=length,
                        special=True,
                        upper=not is_hex_key,
                        lower=not is_hex_key,
                        numeric=not is_hex_key,
                        min_special=length if is_hex_key else 0,
                        override_special="0123456789abcdef"
                        if is_hex_key
                        else "!#$%&*()-_=+[]{}<>:?",
                        opts=pulumi.ResourceOptions(
                            provider=opts.provider if opts else provider
                        ),
                    )
                    secret_data[secret_key] = password.result
                    auto_secret_resources.append(password)

                # Create the dedicated Secret
                auto_k8s_secret = k8s.core.v1.Secret(
                    f"{self._model.name}-{secret_name}",
                    metadata=k8s.meta.v1.ObjectMetaArgs(
                        name=secret_name,
                        namespace=self._model.namespace,
                    ),
                    string_data=secret_data,
                    opts=pulumi.ResourceOptions(
                        provider=opts.provider if opts else provider
                    ),
                )
                auto_secret_resources.append(auto_k8s_secret)

        if self._model.database and self._model.database.local:
            db_host = (
                f"{self._model.name}-db-rw.{self._model.namespace}.svc.cluster.local"
            )
            # We don't put DB_PASSWORD here because it's a secret reference, we keep it in the Helm values or inject it separately
            config_secret_data.update(
                {
                    "DATABASE_URL": f"postgresql://{self._model.name}:{self._model.name}@{db_host}:5432/{self._model.name}",
                    "DB_HOST": db_host,
                    "DB_PORT": "5432",
                    "DB_NAME": self._model.name,
                    "DB_USER": self._model.name,
                }
            )

        config_secret = None
        if config_secret_data:
            config_secret = k8s.core.v1.Secret(
                f"{self._model.name}-config",
                metadata=k8s.meta.v1.ObjectMetaArgs(
                    name=f"{self._model.name}-config-secret",
                    namespace=self._model.namespace,
                ),
                string_data=config_secret_data,
                opts=pulumi.ResourceOptions(provider=provider),
            )

        # 1. Inject unified Config Secret via envFrom
        if config_secret_data:
            secret_ref = {"secretRef": {"name": f"{self._model.name}-config-secret"}}

            if self._model.name == "authentik":
                for comp in ["server", "worker"]:
                    if comp not in final_values:
                        final_values[comp] = {}
                    if "envFrom" not in final_values[comp]:
                        final_values[comp]["envFrom"] = []
                    final_values[comp]["envFrom"].append(secret_ref)
            else:
                if "global" not in final_values:
                    final_values["global"] = {}
                if "envFrom" not in final_values["global"]:
                    final_values["global"]["envFrom"] = []
                final_values["global"]["envFrom"].append(secret_ref)

                if "controllers" in final_values:
                    for ctrl_name, ctrl_val in final_values["controllers"].items():
                        if "containers" in ctrl_val:
                            for cont_name, cont_val in ctrl_val["containers"].items():
                                if "envFrom" not in cont_val:
                                    cont_val["envFrom"] = []
                                cont_val["envFrom"].append(secret_ref)

        # 2. Inject InitContainer for database wait
        if self._model.database and self._model.database.local:
            db_host = (
                f"{self._model.name}-db-rw.{self._model.namespace}.svc.cluster.local"
            )
            wait_container = {
                "name": "wait-for-database",
                "image": "alpine:latest",
                "command": [
                    "sh",
                    "-c",
                    f"apk add --no-cache postgresql-client && until pg_isready -h {db_host} -p 5432; do echo waiting for database; sleep 2; done;",
                ],
            }

            # Common App-Template format
            if "controllers" in final_values:
                for ctrl_name, ctrl_val in final_values["controllers"].items():
                    if "initContainers" not in ctrl_val:
                        ctrl_val["initContainers"] = {}
                    ctrl_val["initContainers"]["wait-for-database"] = wait_container

            # Authentik or custom charts that support bare initContainers
            elif self._model.name == "authentik":
                pass  # Authentik's worker/server crash loop is fine if we fix the env vars. Its chart makes injecting initContainers very difficult without a custom values structure. Wait, Authentik worker supports initContainers. But let's skip it if the config secret works.

        if self._model.name == "authentik":
            import json

            print(
                f"DEBUG AUTHENTIK SERVER ENV: {json.dumps(final_values.get('server', {}).get('env', []), indent=2)}"
            )
            print(
                f"DEBUG AUTHENTIK WORKER ENV: {json.dumps(final_values.get('worker', {}).get('env', []), indent=2)}"
            )

        release_args = helm.ReleaseArgs(
            name=self._model.name,
            chart=actual_chart,
            version=chart_version,
            values=final_values,
            namespace=self._model.namespace,
            timeout=600,
            skip_crds=self._model.skip_crds,
            skip_await=True,
        )

        if not is_oci:
            release_args.repository_opts = helm.RepositoryOptsArgs(repo=repo_url)

        local_opts = opts or pulumi.ResourceOptions()

        release_depends_on = [config_secret] if config_secret else []
        if local_opts.depends_on:
            if isinstance(local_opts.depends_on, list):
                release_depends_on.extend(local_opts.depends_on)
            else:
                release_depends_on.append(local_opts.depends_on)
        local_opts.depends_on = release_depends_on

        release = helm.Release(
            self._model.name,
            release_args,
            opts=local_opts,
        )

        return {"release": release, "config_secret": config_secret}


def create_generic_app(model: AppModel) -> GenericHelmApp:
    return GenericHelmApp(model)
