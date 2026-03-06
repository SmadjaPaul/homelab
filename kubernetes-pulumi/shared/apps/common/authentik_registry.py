import pulumi
from typing import List, Dict, Any, Optional
import subprocess
import json
from shared.utils.schemas import AppModel, ExposureMode
from shared.apps.common.authentik_mgmt import AuthentikDirectory, AuthentikRecovery


class AuthentikRegistry:
    def __init__(
        self, config: Dict[str, Any], domain: str, parent: pulumi.ComponentResource
    ):
        self.config = config
        self.domain = domain
        self.parent = parent
        self.authentik_groups = {}
        self.proxy_provider_ids = []

    def setup_identities(self, authentik_provider: pulumi.ProviderResource):
        identities = self.config.get("identities")
        if not identities or not hasattr(identities, "users"):
            print(
                "  [Registry] No valid identities configuration found, skipping SSO identities setup."
            )
            return

        try:
            import pulumi_authentik as authentik
        except ImportError:
            print(
                "  [Registry] Warning: pulumi-authentik is not installed. Skipping SSO identities setup."
            )
            return

        print("  [Registry] Provisioning Authentik Groups and Users...")
        self.authentik_groups = {}
        for group in identities.groups:
            self.authentik_groups[group.name] = authentik.core.Group(
                f"auth-group-{group.name}",
                name=group.name,
                is_superuser=group.is_superuser,
                opts=pulumi.ResourceOptions(
                    parent=self.parent, provider=authentik_provider
                ),
            )

        for user in identities.users:
            group_ids = [
                self.authentik_groups[g].id
                for g in user.groups
                if g in self.authentik_groups
            ]
            authentik.core.User(
                f"auth-user-{user.name}",
                username=user.name,
                name=user.display_name or user.name,
                email=user.email,
                groups=group_ids,
                attributes=user.attributes,
                opts=pulumi.ResourceOptions(
                    parent=self.parent, provider=authentik_provider
                ),
            )

    def configure_authentik_directory(
        self, authentik_provider: pulumi.ProviderResource, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        print("  [Registry] Provisioning Authentik User Directory...")
        try:
            res = subprocess.check_output(
                [
                    "doppler",
                    "secrets",
                    "get",
                    "AUTH0_USERS",
                    "--plain",
                    "--project",
                    "infrastructure",
                    "--config",
                    "prd",
                ],
                stderr=subprocess.DEVNULL,
            )
            users_data = json.loads(res)
        except Exception as e:
            print(f"  [Registry] Warning: Could not fetch users from Doppler: {e}")
            users_data = {}

        pulumi.ResourceOptions.merge(opts, pulumi.ResourceOptions(parent=self.parent))
        directory = AuthentikDirectory(users_data, authentik_provider)
        recovery = AuthentikRecovery(authentik_provider)
        return directory.provision() + recovery.setup()

    def configure_authentik_layer(
        self,
        apps: List[AppModel],
        authentik_provider: pulumi.ProviderResource,
        opts: pulumi.ResourceOptions,
    ) -> List[pulumi.Resource]:
        resources = []
        resources.extend(self.configure_authentik_directory(authentik_provider, opts))

        try:
            import pulumi_authentik as authentik
        except ImportError:
            print(
                "  [Registry] pulumi_authentik not installed, skipping auth configuration."
            )
            return []

        base_opts = pulumi.ResourceOptions.merge(
            opts, pulumi.ResourceOptions(provider=authentik_provider)
        )
        self.proxy_provider_ids = []

        for app in apps:
            if not getattr(app, "auth", False):
                continue
            hostname = app.hostname
            if not hostname:
                continue

            print(
                f"  [Registry] Configuring Authentik for {app.name} (mode: {app.mode.value})"
            )

            if app.mode == ExposureMode.PROTECTED:
                provider = authentik.ProviderProxy(
                    f"proxy-provider-{app.name}",
                    name=f"{app.name}-proxy",
                    internal_host=f"http://{app.name}.{app.namespace}.svc.cluster.local:{app.port}",
                    external_host=f"https://{hostname}",
                    mode="proxy",
                    authorization_flow="c8badb70-eb62-415c-ad9b-095fafbfae9d",
                    invalidation_flow="3930e55c-b186-47cb-b13d-0ca5eb307eb5",
                    opts=base_opts,
                )
                self.proxy_provider_ids.append(provider.id)
            else:
                if app.name == "homarr":
                    redirect_urls = [
                        {
                            "url": f"https://{hostname}/api/auth/callback/oidc",
                            "matching_mode": "strict",
                        },
                        {
                            "url": "http://localhost:50575/api/auth/callback/oidc",
                            "matching_mode": "strict",
                        },
                    ]
                elif app.name == "vaultwarden":
                    redirect_urls = [
                        {
                            "url": f"https://{hostname}/identity/connect/oidc-signin",
                            "matching_mode": "strict",
                        }
                    ]
                else:
                    redirect_urls = [
                        {
                            "url": f"https://{hostname}/oauth2/callback",
                            "matching_mode": "strict",
                        }
                    ]

                client_secret = (
                    app.extra_env.get("AUTH_OIDC_CLIENT_SECRET")
                    if hasattr(app, "extra_env")
                    else None
                )
                provider = authentik.ProviderOauth2(
                    f"oauth2-provider-{app.name}",
                    name=f"{app.name}-oidc",
                    client_id=f"{app.name}-client",
                    client_secret=client_secret,
                    client_type="confidential",
                    authorization_flow="c8badb70-eb62-415c-ad9b-095fafbfae9d",
                    invalidation_flow="3930e55c-b186-47cb-b13d-0ca5eb307eb5",
                    allowed_redirect_uris=redirect_urls,
                    opts=base_opts,
                )

            resources.append(provider)
            appl = authentik.Application(
                f"auth-app-{app.name}",
                name=app.name.capitalize(),
                slug=app.name,
                protocol_provider=provider.id,
                meta_launch_url=f"https://{hostname}",
                opts=base_opts,
            )
            resources.append(appl)
        return resources

    def finalize_authentik_outpost(
        self,
        authentik_provider: pulumi.ProviderResource,
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> List[pulumi.Resource]:
        resources = []
        if not self.proxy_provider_ids:
            return resources

        try:
            import pulumi_authentik as authentik
        except ImportError:
            return resources

        print(
            f"  [Registry] Creating Authentik Outpost with {len(self.proxy_provider_ids)} providers..."
        )
        base_opts = pulumi.ResourceOptions(
            parent=self.parent, provider=authentik_provider
        )
        if opts:
            base_opts = pulumi.ResourceOptions.merge(base_opts, opts)

        svc_conn = authentik.ServiceConnectionKubernetes(
            "authentik-k8s-connection",
            name="Local Kubernetes",
            local=True,
            opts=base_opts,
        )

        outpost_config = pulumi.Output.all(self.domain).apply(
            lambda args: json.dumps(
                {
                    "authentik_host": f"https://auth.{args[0]}",
                    "kubernetes_namespace": "authentik",
                }
            )
        )

        outpost = authentik.Outpost(
            "authentik-embedded-outpost",
            name="authentik-embedded-outpost",
            type="proxy",
            service_connection=svc_conn.id,
            protocol_providers=self.proxy_provider_ids,
            config=outpost_config,
            opts=base_opts,
        )
        resources.append(svc_conn)
        resources.append(outpost)
        print("  [Registry] Authentik Outpost created.")
        return resources
