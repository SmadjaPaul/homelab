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
from shared.constants import AUTHENTIK_NAMESPACE, AUTHENTIK_OUTPOST_NAME


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
        # Flow IDs resolved dynamically via _lookup_flows()
        self.flow_authorization = None
        self.flow_invalidation = None

        # Initialize OIDC scope attributes to avoid AttributeError if lookups fail
        self._oidc_scope_openid = None
        self._oidc_scope_email = None
        self._oidc_scope_profile = None
        self._signing_keypair = None

    def configure_authentik_directory(
        self, authentik_provider: pulumi.ProviderResource, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        print("  [Registry] Provisioning Authentik User Directory...")

        # Prefer AUTH0_USERS env var (injected by stack_manager.py) over subprocess
        import os

        users_json = os.environ.get("AUTH0_USERS")
        if users_json:
            users_data = json.loads(users_json)
        else:
            # Fallback: subprocess (when running pulumi up directly)
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

    def _lookup_flows(self, authentik_provider: pulumi.ProviderResource):
        """Resolve flow UUIDs dynamically by slug instead of hardcoding."""
        import pulumi_authentik as authentik
        from shared.constants import FLOW_AUTHORIZATION_SLUG, FLOW_INVALIDATION_SLUG

        auth_flow = authentik.get_flow_output(
            slug=FLOW_AUTHORIZATION_SLUG,
            opts=pulumi.InvokeOptions(provider=authentik_provider),
        )
        inv_flow = authentik.get_flow_output(
            slug=FLOW_INVALIDATION_SLUG,
            opts=pulumi.InvokeOptions(provider=authentik_provider),
        )
        self.flow_authorization = auth_flow.id
        self.flow_invalidation = inv_flow.id

    def _get_redirect_uris(self, app: AppModel) -> List[Dict[str, str]]:
        """Determine redirect URIs based on app config or convention."""
        if app.provisioning and app.provisioning.redirect_uris:
            return [
                {"url": u, "matching_mode": "strict"}
                for u in app.provisioning.redirect_uris
            ]

        # Conventions for apps that don't specify redirect URIs
        convention = {
            "vaultwarden": ["/identity/connect/oidc-signin"],
            "audiobookshelf": [
                "/auth/openid/callback",
                "/auth/openid/mobile-redirect",
            ],
            "open-webui": ["/oauth/oidc/callback"],
            "immich": [
                "/auth/login",
                "/user-settings",
                "app.immich:///oauth-callback",
            ],
            "nextcloud": ["/apps/user_oidc/code"],
            "romm": ["/api/oauth2/openid/callback"],
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
        print(f"  [Registry] configure_authentik_layer starting with {len(apps)} apps")
        resources = []
        self._lookup_flows(authentik_provider)
        resources.extend(self.configure_authentik_directory(authentik_provider, opts))

        try:
            import pulumi_authentik as authentik
        except ImportError:
            print(
                "  [Registry] pulumi_authentik not installed, skipping auth configuration."
            )
            return []

        # Standard flows - use class attributes

        base_opts = pulumi.ResourceOptions.merge(
            opts,
            pulumi.ResourceOptions(provider=authentik_provider, parent=self.parent),
        )

        try:
            # Look up Authentik's built-in self-signed certificate for JWT signing.
            # This ensures OIDC access tokens include a 'kid' header that apps (e.g. OCIS)
            # can verify against the JWKS endpoint.
            self._signing_keypair = authentik.get_certificate_key_pair_output(
                name="authentik Self-signed Certificate",
                opts=pulumi.InvokeOptions(provider=authentik_provider),
            )
            if not self._signing_keypair:
                pulumi.log.error(
                    "  [Registry] CRITICAL: Could not find 'authentik Self-signed Certificate' for OIDC signing!"
                )

            # Look up built-in OIDC scope mappings for token claims
            self._oidc_scope_openid = (
                authentik.get_property_mapping_provider_scope_output(
                    managed="goauthentik.io/providers/oauth2/scope-openid",
                    opts=pulumi.InvokeOptions(provider=authentik_provider),
                )
            )
            self._oidc_scope_email = (
                authentik.get_property_mapping_provider_scope_output(
                    managed="goauthentik.io/providers/oauth2/scope-email",
                    opts=pulumi.InvokeOptions(provider=authentik_provider),
                )
            )
            self._oidc_scope_profile = (
                authentik.get_property_mapping_provider_scope_output(
                    managed="goauthentik.io/providers/oauth2/scope-profile",
                    opts=pulumi.InvokeOptions(provider=authentik_provider),
                )
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
                expression='return user.email or f"{user.username}@homelab.internal"',
                opts=base_opts,
            )
            mapping_name = authentik.ScopeMapping(
                "auth-mapping-name",
                name="homelab-proxy-mapping-name",
                scope_name="name",
                expression="return user.name or user.username",
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
            # Vaultwarden requires email_verified=True in the OIDC token.
            # Without this, Vaultwarden rejects the login.
            mapping_vaultwarden_email = authentik.ScopeMapping(
                "auth-mapping-vaultwarden-email",
                name="Vaultwarden Email Scope",
                scope_name="email",
                expression="return {'email': request.user.email, 'email_verified': True}",
                opts=base_opts,
            )
            resources.extend(
                [
                    mapping_username,
                    mapping_email,
                    mapping_name,
                    mapping_uid,
                    mapping_groups,
                    mapping_vaultwarden_email,
                ]
            )
        except Exception as e:
            print(f"  [Registry] ERROR during Authentik layer initialization: {e}")
            # We continue to the loop anyway to see if we can provision apps
            pass

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
                    internal_host=f"http://{app.service_name or app.name}.{app.namespace}.svc.cluster.local:{app.port}",
                    external_host=f"https://{hostname}",
                    mode="proxy",
                    intercept_header_auth=False,
                    authorization_flow=self.flow_authorization,
                    invalidation_flow=self.flow_invalidation,
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
                        pulumi.ResourceOptions(),
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
                client_id = app.provisioning.client_id or f"{app.name}-oidc"

                # Standard scopes lookup with fallback
                property_mappings = []
                if self._oidc_scope_openid:
                    property_mappings.append(self._oidc_scope_openid.id)
                if self._oidc_scope_email:
                    property_mappings.append(self._oidc_scope_email.id)
                if self._oidc_scope_profile:
                    property_mappings.append(self._oidc_scope_profile.id)

                # Vaultwarden-specific: add email_verified scope + offline_access
                oidc_extra_kwargs = {}
                if app.name == "vaultwarden":
                    property_mappings.append(mapping_vaultwarden_email.id)
                    # offline_access scope for session refresh
                    try:
                        offline_scope = authentik.get_property_mapping_provider_scope_output(
                            managed="goauthentik.io/providers/oauth2/scope-offline_access",
                            opts=pulumi.InvokeOptions(provider=authentik_provider),
                        )
                        property_mappings.append(offline_scope.id)
                    except Exception:
                        pass
                    # Access token must be > 5 minutes (Vaultwarden requirement)
                    oidc_extra_kwargs["access_token_validity"] = "minutes=10"

                oidc_kwargs = dict(
                    name=app.provisioning.name or f"{app.name}-oidc",
                    client_id=client_id,
                    authorization_flow=self.flow_authorization,
                    invalidation_flow=self.flow_invalidation,
                    allowed_redirect_uris=redirect_uris,
                    signing_key=self._signing_keypair.id
                    if self._signing_keypair
                    else None,
                    property_mappings=property_mappings,
                    opts=base_opts,
                    **oidc_extra_kwargs,
                )

                oidc_provider = authentik.ProviderOauth2(
                    f"oidc-provider-{app.name}",
                    **oidc_kwargs,
                )
                resources.append(oidc_provider)

                oidc_slug = f"{app.name}-oidc"
                is_public = app.mode == ExposureMode.PUBLIC
                resources.append(
                    authentik.Application(
                        f"auth-app-{app.name}-oidc",
                        name=f"{app.name.capitalize()} (OIDC)",
                        slug=oidc_slug,
                        protocol_provider=oidc_provider.id,
                        # Hide from dashboard unless it's the main entry point (PUBLIC mode)
                        # The 'blank://blank' URL pattern is recognized as 'hidden' or 'unclickable'
                        meta_launch_url=f"https://{hostname}"
                        if is_public
                        else "blank://blank",
                        open_in_new_tab=is_public,
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
                        "nginx.ingress.kubernetes.io/proxy-buffer-size": "16k",
                        "nginx.ingress.kubernetes.io/proxy-buffers-number": "4",
                        "nginx.ingress.kubernetes.io/proxy-busy-buffers-size": "32k",
                    },
                }
            )
        )

        # --- LDAP Outpost ---
        ldap_provider = authentik.ProviderLdap(
            "ldap-provider-homelab",
            name="homelab-ldap-provider",
            base_dn="dc=authentik,dc=cluster,dc=local",
            bind_flow=self.flow_authorization,
            unbind_flow=self.flow_invalidation,
            opts=base_opts,
        )
        resources.append(ldap_provider)

        ldap_app = authentik.Application(
            "auth-app-ldap",
            name="LDAP Directory",
            slug="ldap",
            protocol_provider=ldap_provider.id,
            meta_launch_url="blank://blank",
            opts=base_opts,
        )
        resources.append(ldap_app)

        ldap_outpost = authentik.Outpost(
            "authentik-ldap-outpost",
            # Type must be 'ldap' for LDAP providers
            name="authentik-ldap-outpost",
            type="ldap",
            service_connection=svc_conn.id,
            protocol_providers=[ldap_provider.id],
            config=outpost_config,
            opts=pulumi.ResourceOptions.merge(
                base_opts, pulumi.ResourceOptions(depends_on=[svc_conn, ldap_provider])
            ),
        )
        resources.append(ldap_outpost)

        outpost = authentik.Outpost(
            "authentik-embedded-outpost",
            name=AUTHENTIK_OUTPOST_NAME,
            type="proxy",
            service_connection=svc_conn.id,
            protocol_providers=self.proxy_provider_ids,
            config=outpost_config,
            opts=pulumi.ResourceOptions.merge(
                base_opts, pulumi.ResourceOptions(depends_on=[svc_conn])
            ),
        )
        resources.append(svc_conn)
        resources.append(outpost)

        # Fix Authentik 2026.2.1: outpost service gets wrong selector
        # (includes app.kubernetes.io/component: server which pods don't have).
        # We create a CUSTOM service in Pulumi with the correct selector.
        import pulumi_kubernetes as k8s

        # Minimal selector that matches the outpost pods
        outpost_svc_selector = {
            "app": "authentik-outpost",
            "goauthentik.io/outpost-name": AUTHENTIK_OUTPOST_NAME,
            "goauthentik.io/outpost-type": "proxy",
        }

        outpost_svc = k8s.core.v1.Service(
            "ak-outpost-svc-custom",
            metadata=k8s.meta.v1.ObjectMetaArgs(
                name="ak-outpost-custom",
                namespace=AUTHENTIK_NAMESPACE,
            ),
            spec=k8s.core.v1.ServiceSpecArgs(
                selector=outpost_svc_selector,
                ports=[
                    k8s.core.v1.ServicePortArgs(
                        name="http", port=9000, target_port=9000, protocol="TCP"
                    ),
                    k8s.core.v1.ServicePortArgs(
                        name="http-metrics", port=9300, target_port=9300, protocol="TCP"
                    ),
                    k8s.core.v1.ServicePortArgs(
                        name="https", port=9443, target_port=9443, protocol="TCP"
                    ),
                ],
            ),
            opts=pulumi.ResourceOptions(parent=self.parent, depends_on=[outpost]),
        )
        resources.append(outpost_svc)

        # Create a dedicated Ingress for auth.smadja.dev so external-dns creates a CNAME.
        # The Outpost Ingress only covers protected-app hostnames. auth.smadja.dev
        # (mode: public) would otherwise have no DNS record.
        # NOTE: Resources must NOT be created inside .apply() callbacks — use Output values
        # directly as resource properties instead (Pulumi resolves them automatically).
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
