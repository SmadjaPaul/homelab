"""
Manages Authentik SSO configuration for applications.

IMPORTANT: The Outpost Ingress is annotated with:
  external-dns.alpha.kubernetes.io/target: <tunnel-id>.cfargotunnel.com
This causes external-dns to auto-create CNAME records for all protected hostnames.

RELATED FILES:
  - shared/networking/cloudflare/exposure_manager.py: TunnelManager — tunnel routing
  - shared/apps/impl/cloudflared.py: Deploys the tunnel pod
  - apps.yaml: Source of truth for auth mode (protected/public/internal)
  - shared/constants.py: Authentik outpost URL, flow slugs
"""

import pulumi
from typing import List, Dict, Any, Optional
import json
import pulumiverse_doppler as doppler
from shared.utils.schemas import AppModel, ExposureMode, ProvisioningMethod
from shared.apps.common.authentik_mgmt import AuthentikDirectory, AuthentikRecovery


class AuthentikRegistry:
    def __init__(
        self,
        config: Dict[str, Any],
        domain: str,
        parent: pulumi.ComponentResource,
        doppler_provider: Optional[pulumi.ProviderResource] = None,
    ):
        self.config = config
        self.domain = domain
        self.parent = parent
        self.doppler_provider = doppler_provider
        self.tunnel_id = config.get("cloudflare_tunnel_id")
        self.authentik_groups = {}
        self.proxy_provider_ids = []
        self.public_hostnames = []

    def setup_identities(self, authentik_provider: pulumi.ProviderResource):
        # Handle both dict and Pydantic model
        identities = self.config.get("identities")
        print(f"  [Registry] identities raw type: {type(identities)}")
        if not identities:
            print("  [Registry] No identities block found in config.")
            return

        users = identities.get("users", [])
        groups = identities.get("groups", [])

        print(
            f"  [Registry] setup_identities found {len(users)} users and {len(groups)} groups."
        )
        if not users and not groups:
            print(
                f"  [Registry] Identities config empty or invalid. Users exist? {users is not None}, Groups exist? {groups is not None}"
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
        for group in groups if isinstance(groups, list) else (groups or []):
            name = group["name"] if isinstance(group, dict) else group.name
            is_superuser = (
                group.get("is_superuser", False)
                if isinstance(group, dict)
                else group.is_superuser
            )
            self.authentik_groups[name] = authentik.Group(
                f"auth-group-{name}",
                name=name,
                is_superuser=is_superuser,
                opts=pulumi.ResourceOptions(
                    parent=self.parent, provider=authentik_provider
                ),
            )

        for user in users if users else []:
            u_name = user["name"] if isinstance(user, dict) else user.name
            u_display_name = (
                (user.get("display_name") or u_name)
                if isinstance(user, dict)
                else (user.display_name or user.name)
            )
            u_email = user.get("email") if isinstance(user, dict) else user.email
            u_groups = user.get("groups", []) if isinstance(user, dict) else user.groups
            u_attributes = (
                user.get("attributes", {})
                if isinstance(user, dict)
                else user.attributes
            )

            group_ids = [
                self.authentik_groups[g].id
                for g in u_groups
                if g in self.authentik_groups
            ]
            import json

            user_opts = pulumi.ResourceOptions(
                parent=self.parent, provider=authentik_provider
            )

            authentik.User(
                f"ak-user-{u_name}",
                username=u_name,
                name=u_display_name,
                email=u_email,
                groups=group_ids,
                attributes=json.dumps(u_attributes),
                opts=user_opts,
            )

    def configure_authentik_directory(
        self, authentik_provider: pulumi.ProviderResource, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        print("  [Registry] Provisioning Authentik User Directory...")

        # NOTE: We use subprocess here intentionally.
        # `doppler_secrets` in config is a pulumi.Output[dict] which cannot be consumed
        # synchronously inside a regular Python method. Using Output.get(key, default)
        # triggers Pulumi's Output.get() which only accepts 1 argument and raises an error.
        # The subprocess call is a deliberate escape hatch for this startup-time data fetch.
        import subprocess

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
        resources, self.flow_ids = recovery.setup()
        return directory.provision() + resources

    def _get_redirect_uris(self, app: AppModel) -> List[Dict[str, str]]:
        """Determine redirect URIs based on app config or convention."""
        if app.provisioning and app.provisioning.redirect_uris:
            return [
                {"url": u, "matching_mode": "strict"}
                for u in app.provisioning.redirect_uris
            ]

        # Conventions for apps that don't specify redirect URIs
        convention = {
            "opencloud": ["/oidc-callback.html"],
            "vaultwarden": ["/identity/connect/oidc-signin"],
            "audiobookshelf": [
                "/auth/openid/callback",
                "/auth/openid/mobile-redirect",
            ],
            "open-webui": ["/oauth/oidc/callback"],
        }

        hostname = app.hostname
        paths = convention.get(app.name, ["/oauth2/callback"])
        return [
            {"url": f"https://{hostname}{p}", "matching_mode": "strict"} for p in paths
        ]

    def configure_authentik_layer(
        self,
        apps: List[AppModel],
        authentik_provider: pulumi.ProviderResource,
        opts: pulumi.ResourceOptions,
    ) -> List[pulumi.Resource]:
        """Phase 2: Provision Authentik Proxy or OAuth2 Providers and Applications for all apps."""
        resources = []
        resources.extend(self.configure_authentik_directory(authentik_provider, opts))

        try:
            import pulumi_authentik as authentik
        except ImportError:
            print(
                "  [Registry] pulumi_authentik not installed, skipping auth configuration."
            )
            return []

        # Standard flows - Using fixed default UUIDs for stability
        # Note: Authentik Provider expects UUIDs, not slugs. These are the default flow UUIDs.
        flow_authorization = "306d2f7d-4b4c-4bbe-81bb-dccebe9b3264"  # default-provider-authorization-implicit-consent
        flow_invalidation = (
            "ad1278c4-fb2b-4a91-b063-a24aab34f7bb"  # default-invalidation-flow
        )

        base_opts = pulumi.ResourceOptions.merge(
            opts,
            pulumi.ResourceOptions(provider=authentik_provider, parent=self.parent),
        )

        # Standard Proxy Mappings (reverted to ScopeMapping because ProxyPropertyMapping is missing in this provider)
        mapping_username = authentik.ScopeMapping(
            "auth-mapping-username",
            name="homelab-proxy-mapping-username",
            scope_name="username",
            expression="return user.username",
            opts=base_opts,
        )
        mapping_email = authentik.ScopeMapping(
            "auth-mapping-email",
            name="homelab-proxy-mapping-email",
            scope_name="email",
            expression="return user.email",
            opts=base_opts,
        )
        mapping_name = authentik.ScopeMapping(
            "auth-mapping-name",
            name="homelab-proxy-mapping-name",
            scope_name="name",
            expression="return user.name",
            opts=base_opts,
        )
        mapping_uid = authentik.ScopeMapping(
            "auth-mapping-uid",
            name="homelab-proxy-mapping-uid",
            scope_name="uid",
            expression="return user.pk",
            opts=base_opts,
        )
        mapping_groups = authentik.ScopeMapping(
            "auth-mapping-groups",
            name="homelab-proxy-mapping-groups",
            scope_name="groups",
            expression='return ",".join([g.name for g in user.ak_groups.all()])',
            opts=base_opts,
        )

        self.proxy_provider_ids = []

        for app in apps:
            if not getattr(app, "auth", False):
                continue
            hostname = app.hostname
            if not hostname:
                continue

            print(
                f"  [Registry] Configuring Authentik for {app.name} (mode: {app.mode.value}, hostname: {hostname})"
            )

            # --- Layer 1: Security Gate (Proxy) ---
            # Used for PROTECTED apps to provide a common login wall.
            main_provider = None
            if app.mode == ExposureMode.PROTECTED:
                main_provider = authentik.ProviderProxy(
                    f"proxy-provider-{app.name}",
                    name=f"proxy-provider-{app.name}",
                    internal_host=f"http://{app.name}.{app.namespace}.svc.cluster.local:{app.port}",
                    external_host=f"https://{hostname}",
                    mode="proxy",
                    authorization_flow=flow_authorization,
                    invalidation_flow=flow_invalidation,
                    property_mappings=[
                        mapping_username.id,
                        mapping_email.id,
                        mapping_name.id,
                        mapping_uid.id,
                        mapping_groups.id,
                    ],
                    cookie_domain=self.domain.apply(lambda d: f".{d}"),
                    opts=pulumi.ResourceOptions.merge(
                        base_opts,
                        pulumi.ResourceOptions(
                            ignore_changes=["property_mappings", "cookie_domain"],
                        ),
                    ),
                )
                self.proxy_provider_ids.append(main_provider.id)
                resources.append(main_provider)

                # Proxy Application (The visible 'dashboard' icon for the gateway)
                resources.append(
                    authentik.Application(
                        f"auth-app-{app.name}",
                        name=app.name.capitalize(),
                        slug=app.name,
                        protocol_provider=main_provider.id,
                        meta_launch_url=f"https://{hostname}",
                        opts=base_opts,
                    )
                )

            # --- Layer 2: Provisioning (OIDC) ---
            # Used for JIT account creation, either as the main provider (PUBLIC)
            # or as a sidecar provider (PROTECTED dual-layer).
            if app.provisioning and app.provisioning.method == ProvisioningMethod.OIDC:
                redirect_uris = self._get_redirect_uris(app)
                client_id = app.provisioning.client_id or f"{app.name}-client"

                oidc_provider = authentik.ProviderOauth2(
                    f"oidc-provider-{app.name}",
                    name=app.provisioning.name or f"{app.name}-oidc",
                    client_id=client_id,
                    authorization_flow=flow_authorization,
                    invalidation_flow=flow_invalidation,
                    allowed_redirect_uris=redirect_uris,
                    opts=base_opts,
                )
                resources.append(oidc_provider)

                # OIDC Sidecar Application (Hidden from dashboard, used for Discovery)
                # This fixes "Impossible de résoudre l'application" errors.
                # If app is PROTECTED, we use suffix -oidc to avoid slug conflict.
                oidc_slug = f"{app.name}-oidc"
                resources.append(
                    authentik.Application(
                        f"auth-app-{app.name}-oidc",
                        name=f"{app.name.capitalize()} (OIDC)",
                        slug=oidc_slug,
                        protocol_provider=oidc_provider.id,
                        # Hide from dashboard unless it's the main entry point
                        meta_launch_url=f"https://{hostname}"
                        if app.mode == ExposureMode.PUBLIC
                        else None,
                        opts=base_opts,
                    )
                )

                # Auto-push secret to Doppler if provider is available
                if self.doppler_provider:
                    secret_key = (
                        app.provisioning.client_secret_key
                        or f"{app.name.upper().replace('-', '_')}_OIDC_CLIENT_SECRET"
                    )
                    doppler.Secret(
                        f"doppler-secret-{app.name}-oidc",
                        project="infrastructure",
                        config="prd",
                        name=secret_key,
                        value=oidc_provider.client_secret,
                        opts=pulumi.ResourceOptions(
                            parent=self.parent, provider=self.doppler_provider
                        ),
                    )

                if app.mode == ExposureMode.PUBLIC:
                    self.public_hostnames.append(hostname)

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

        outpost_config = pulumi.Output.all(self.domain, self.tunnel_id).apply(
            lambda args: json.dumps(
                {
                    # IMPORTANT: authentik_host must be the internal K8s service URL,
                    # not the external domain. The external domain doesn't resolve inside
                    # the cluster and causes the outpost to fail with "no such host".
                    "authentik_host": "http://authentik-server.authentik.svc.cluster.local",
                    # authentik_host_browser is the URL users' browsers are redirected to
                    # for the login page (this IS the external URL).
                    "authentik_host_browser": f"https://auth.{args[0]}",
                    "kubernetes_namespace": "authentik",
                    "kubernetes_ingress_annotations": {
                        "external-dns.alpha.kubernetes.io/target": f"{args[1]}.cfargotunnel.com",
                        "external-dns.alpha.kubernetes.io/cloudflare-proxied": "true",
                    },
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

        # Create a dedicated Ingress for auth.smadja.dev so external-dns creates a CNAME.
        # The Outpost Ingress only covers protected-app hostnames. auth.smadja.dev
        # (mode: public) would otherwise have no DNS record.
        # NOTE: Resources must NOT be created inside .apply() callbacks — use Output values
        # directly as resource properties instead (Pulumi resolves them automatically).
        import pulumi_kubernetes as k8s

        tunnel_target = self.tunnel_id.apply(lambda tid: f"{tid}.cfargotunnel.com")

        # Collect all public hostnames that need DNS but aren't in the Outpost Ingress.
        # Ensure auth domain is always included. Handle self.domain as an Output.
        auth_hostname = self.domain.apply(lambda d: f"auth.{d}")

        # Merge public_hostnames (which might be strings or outputs) with auth_hostname.
        # We use Output.all to safely create the list of rules.
        all_hosts_output = pulumi.Output.all(auth_hostname, *self.public_hostnames)

        def create_rules(hosts):
            rules = []
            # Remove duplicates and sort for idempotency
            unique_hosts = sorted(list(set(hosts)))
            for host in unique_hosts:
                target_svc = "authentik-server"
                target_port = 80

                if "vault." in str(host):
                    target_svc = "vaultwarden"
                    target_port = 8080

                rules.append(
                    k8s.networking.v1.IngressRuleArgs(
                        host=host,
                        http=k8s.networking.v1.HTTPIngressRuleValueArgs(
                            paths=[
                                k8s.networking.v1.HTTPIngressPathArgs(
                                    path="/",
                                    path_type="Prefix",
                                    backend=k8s.networking.v1.IngressBackendArgs(
                                        service=k8s.networking.v1.IngressServiceBackendArgs(
                                            name=target_svc,
                                            port=k8s.networking.v1.ServiceBackendPortArgs(
                                                number=target_port,
                                            ),
                                        ),
                                    ),
                                )
                            ],
                        ),
                    )
                )
            return rules

        ingress_rules = all_hosts_output.apply(create_rules)

        auth_ingress = k8s.networking.v1.Ingress(
            "authentik-dns-helper",
            metadata=k8s.meta.v1.ObjectMetaArgs(
                name="authentik-dns-helper",
                namespace="authentik",
                annotations={
                    "external-dns.alpha.kubernetes.io/target": tunnel_target,
                    "external-dns.alpha.kubernetes.io/cloudflare-proxied": "true",
                    "pulumi.com/skipAwait": "true",
                },
            ),
            spec=k8s.networking.v1.IngressSpecArgs(
                rules=ingress_rules,
            ),
            opts=pulumi.ResourceOptions(parent=self.parent),
        )
        resources.append(auth_ingress)
        print(
            f"  [Registry] Authentik Outpost and DNS helper created with {len(self.public_hostnames) + 1} public hostnames."
        )
        return resources
