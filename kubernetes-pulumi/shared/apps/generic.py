import pulumi
import pulumi_kubernetes as k8s
import pulumi_kubernetes.helm.v3 as helm
from typing import Optional, Any
from shared.apps.base import BaseApp
from shared.utils.schemas import AppModel


class GenericHelmApp(BaseApp):
    def __init__(self, model: AppModel):
        super().__init__(model)

    def get_final_values(self) -> dict[str, Any]:
        """Provides the final dictionary of Helm values."""
        from shared.apps.adapters import get_adapter

        adapter = get_adapter(self._model)
        return adapter.get_final_values()

    def deploy_components(
        self,
        provider: k8s.Provider,
        config: dict[str, Any],
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> dict[str, Any]:
        chart_name = self._model.helm.chart
        chart_version = self._model.helm.version
        repo_url = self._model.helm.repo

        from shared.apps.adapters import get_adapter

        adapter = get_adapter(self._model)
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

        # 1.1 Process ConfigMaps
        config_map_resources = []
        if self._model.config_maps:
            for cm_req in self._model.config_maps:
                cm = k8s.core.v1.ConfigMap(
                    f"{self._model.name}-{cm_req.name}",
                    metadata=k8s.meta.v1.ObjectMetaArgs(
                        name=cm_req.name,
                        namespace=self._model.namespace,
                    ),
                    data=cm_req.data,
                    opts=pulumi.ResourceOptions(
                        provider=opts.provider if opts else provider
                    ),
                )
                config_map_resources.append(cm)

        if self._model.database and self._model.database.local:
            pass  # DB config now handled by adapters directly in Helm values

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
            adapter.inject_config_secret(final_values, secret_ref)

        # 2. Inject InitContainer for database wait
        if self._model.database and self._model.database.local:
            db_host = "homelab-db-rw.cnpg-system.svc.cluster.local"
            wait_container = {
                "name": "wait-for-database",
                "image": "alpine:latest",
                "command": [
                    "sh",
                    "-c",
                    f"apk add --no-cache postgresql-client && until pg_isready -h {db_host} -p 5432; do echo waiting for database; sleep 2; done;",
                ],
            }
            adapter.inject_init_container_for_db(final_values, wait_container)

        release_args = helm.ReleaseArgs(
            name=self._model.name,
            chart=actual_chart,
            version=chart_version,
            values=final_values,
            namespace=self._model.namespace,
            timeout=1200 if self._model.test.requires_extended_timeout else 600,
            skip_crds=self._model.skip_crds,
            skip_await=True,
        )

        if not is_oci:
            release_args.repository_opts = helm.RepositoryOptsArgs(repo=repo_url)

        local_opts = opts or pulumi.ResourceOptions()

        release_depends_on = [config_secret] if config_secret else []
        if auto_secret_resources:
            release_depends_on.extend(auto_secret_resources)
        if config_map_resources:
            release_depends_on.extend(config_map_resources)
            # Inject ConfigMap mounts via adapter
            adapter.apply_config_maps(final_values)

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
