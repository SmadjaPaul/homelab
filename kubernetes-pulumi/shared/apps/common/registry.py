"""
Unified Application Registry and Exposure Manager
"""

import pulumi
import pulumi_kubernetes as k8s
from typing import List, Dict, Any, Optional
from shared.utils.schemas import AppModel, SecretRequirement, ExposureMode
from shared.apps.common.storagebox import setup_storagebox_automation
import pulumi_command as command
import pulumiverse_doppler as doppler


# Note: ExposureMode and StorageTier are imported from shared.utils.schemas


class AppRegistry(pulumi.ComponentResource):
    """
    Manages exposure (Public/Protected/Internal) and Secret requirements.
    """

    apps: List[AppModel]

    def __init__(
        self,
        name: str,
        provider: k8s.Provider,
        config: Optional[Dict[str, Any]] = None,
        opts: Optional[pulumi.ResourceOptions] = None,
    ):
        super().__init__("homelab:common:AppRegistry", name, {}, opts)
        self.register_outputs({})

        self.provider = provider
        self.config = config or {}
        self.domain = self.config.get("domain", "smadja.dev")
        self.gateway_name = self.config.get("gateway_name", "external")
        self.gateway_namespace = self.config.get("gateway_namespace", "envoy-gateway")
        self._hetzner_smb_ready = False
        from shared.apps.common.storagebox import StorageBoxManager

        self.storagebox_manager: Optional[StorageBoxManager] = None
        self.crd_wait_cmd: Optional[pulumi.Resource] = None
        self.doppler_secrets = doppler.get_secrets_output(
            project="infrastructure", config="prd"
        )

    def setup_global_infrastructure(self):
        """Setup resources that are cluster-wide or shared."""
        # 0. Wait for CRDs (Timing synchronization)
        self._wait_for_crds()

        # 1. Process Authentik Identities (Users & Groups)
        self._setup_identities()

        # 2. Automate Hetzner Storage Box Sub-accounts (via Robot API)
        self._setup_storagebox_automation()

        # 3. Global Quota check (optional/logging)
        # We'll call this after all apps are registered or just once here with all apps
        # But for now, let's keep it simple.

    def register_app(
        self,
        app: AppModel,
        deployed_apps: Optional[Dict[str, Any]] = None,
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> List[pulumi.Resource]:
        """Provision all registry-managed resources for a single application."""
        resources = []
        deployed_apps = deployed_apps or {}
        # Avoid printing Output[T] directly
        pulumi.Output.from_input(app.name).apply(
            lambda name: print(f"  [Registry] Registering {name} in {app.namespace}...")
        )

        # Create localized opts that include the passed-in opts
        local_opts = pulumi.ResourceOptions(provider=self.provider, parent=self)

        # Add dependency on CRD wait if it exists
        if self.crd_wait_cmd:
            local_opts = pulumi.ResourceOptions.merge(
                local_opts, pulumi.ResourceOptions(depends_on=[self.crd_wait_cmd])
            )

        if opts:
            local_opts = pulumi.ResourceOptions.merge(local_opts, opts)

        # 1. Secrets (ExternalSecrets)
        resources.extend(self._setup_secrets_for_app(app, deployed_apps, local_opts))
        resources.extend(self._setup_docker_secrets(app, local_opts))

        # 2. RBAC (ServiceAccounts)
        resources.extend(self._setup_rbac_for_app(app, local_opts))

        # 3. Reliability (PDBs)
        resources.extend(self._setup_reliability_for_app(app, local_opts))

        # 4. Monitoring (ServiceMonitors)
        resources.extend(self._setup_monitoring_for_app(app, deployed_apps, local_opts))

        # 5. Storage (PVCs)
        resources.extend(self._setup_storage_for_app(app, deployed_apps, local_opts))

        # 5.5 Database (CNPG Clusters)
        resources.extend(self._setup_database_for_app(app, local_opts))

        # 6. Authentication (Authentik OIDC)
        resources.extend(self._setup_auth_for_app(app, local_opts))

        # 7. Exposure (Routes/Ingress)
        resources.extend(self._setup_exposure_for_app(app, local_opts))

        return resources

    def _get_standard_labels(self, app: AppModel) -> Dict[str, str]:
        """Return standard Recommended Kubernetes Labels."""
        return {
            "app.kubernetes.io/name": app.name,
            "app.kubernetes.io/instance": app.name,
            "app.kubernetes.io/managed-by": "pulumi",
            "app.kubernetes.io/part-of": "homelab",
            "homelab.dev/tier": app.tier.value,
            "homelab.dev/category": app.category.value,
        }

    def _setup_rbac_for_app(
        self, app: AppModel, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        """Create a dedicated ServiceAccount for each app."""
        labels = self._get_standard_labels(app)
        labels["app.kubernetes.io/managed-by"] = "Helm"

        sa = k8s.core.v1.ServiceAccount(
            f"sa-{app.name}",
            metadata={
                "name": app.name,
                "namespace": app.namespace,
                "labels": labels,
                "annotations": {
                    "meta.helm.sh/release-name": app.name,
                    "meta.helm.sh/release-namespace": app.namespace,
                    "pulumi.com/patchForce": "true",
                },
            },
            opts=opts,
        )
        return [sa]

    def _wait_for_crds(self):
        """
        Wait for CRDs to be established before proceeding.
        This prevents timing issues between stacks.
        """
        # Define the CRDs we need to wait for
        # Primarily external-secrets in this case
        crd_name = "externalsecrets.external-secrets.io"

        # We only run this if we are not in a logic dry-run or unit test that mocks pulumi-command
        # Pulumi Command will naturally handle the skip during preview if we don't set 'create'
        # But here we want it to run during the Up phase.

        self.crd_wait_cmd = command.local.Command(
            f"wait-for-crd-{crd_name}",
            create=f"kubectl wait --for=condition=Established crd/{crd_name} --timeout=60s",
            # Optimization: only run if the CRD isn't already ready (optional, but keep it simple for now)
            # Or just let it run, kubectl wait is fast if already met.
            opts=pulumi.ResourceOptions(parent=self),
        )

    def _setup_reliability_for_app(
        self, app: AppModel, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        """Create PodDisruptionBudget for apps with multiple replicas."""
        if app.replicas > 1:
            pdb = k8s.policy.v1.PodDisruptionBudget(
                f"pdb-{app.name}",
                metadata={
                    "name": app.name,
                    "namespace": app.namespace,
                    "labels": self._get_standard_labels(app),
                },
                spec={
                    "maxUnavailable": 1,
                    "selector": {"matchLabels": {"app.kubernetes.io/name": app.name}},
                },
                opts=opts,
            )
            return [pdb]
        return []

    def _setup_monitoring_for_app(
        self, app: AppModel, deployed_apps: Dict[str, Any], opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        """Provision ServiceMonitor for Prometheus auto-discovery."""
        if not getattr(app, "monitoring", True):
            return []

        # Disable monitoring if prometheus-operator CRD is unlikely to be present
        if (
            "kube-prometheus-stack" not in deployed_apps
            and "prometheus-stack" not in deployed_apps
        ):
            print(
                f"    [Registry] Skipping ServiceMonitor for {app.name} (monitoring operator not found in deployed_apps)"
            )
            return []

        deps = []
        if "kube-prometheus-stack" in deployed_apps and isinstance(
            deployed_apps["kube-prometheus-stack"], pulumi.Resource
        ):
            deps.append(deployed_apps["kube-prometheus-stack"])
        if "prometheus-stack" in deployed_apps and isinstance(
            deployed_apps["prometheus-stack"], pulumi.Resource
        ):
            deps.append(deployed_apps["prometheus-stack"])

        # Merge with existing opts
        local_opts = pulumi.ResourceOptions.merge(
            opts, pulumi.ResourceOptions(depends_on=deps)
        )

        sm = k8s.apiextensions.CustomResource(
            f"servicemonitor-{app.name}",
            api_version="monitoring.coreos.com/v1",
            kind="ServiceMonitor",
            metadata={
                "name": app.name,
                "namespace": app.namespace,
                "labels": {
                    **self._get_standard_labels(app),
                    "release": "prometheus-stack",  # Common label for discovery
                },
            },
            spec={
                "selector": {"matchLabels": {"app.kubernetes.io/name": app.name}},
                "endpoints": [
                    {
                        "port": "http",  # Assumes service port name is 'http'
                        "path": "/metrics",
                        "interval": "30s",
                    }
                ],
            },
            opts=local_opts,
        )
        return [sm]

    def _setup_secrets_for_app(
        self, app: AppModel, deployed_apps: Dict[str, Any], opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        """Provision ExternalSecrets for apps that require them."""
        secrets = []
        for req in app.secrets:
            deps = []
            if deployed_apps.get("external-secrets") and isinstance(
                deployed_apps["external-secrets"], pulumi.Resource
            ):
                deps.append(deployed_apps["external-secrets"])

            local_opts = pulumi.ResourceOptions.merge(
                opts, pulumi.ResourceOptions(depends_on=deps)
            )

            def _verify_keys(args):
                secret_map, req_name, remote_key, keys_val = args
                # Si un remote_key (JSON parent) est défini, c'est la seule clé brute à vérifier dans Doppler
                # Sinon, ce sont les clés individuelles (liste ou dictionnaire de mapping)
                keys_to_check = []
                if remote_key:
                    keys_to_check = [remote_key]
                elif isinstance(keys_val, dict):
                    keys_to_check = list(keys_val.values())
                else:
                    keys_to_check = keys_val

                for k in keys_to_check:
                    if k not in secret_map:
                        raise ValueError(
                            f"CRITICAL ERROR: Secret key '{k}' required by app '{app.name}' is MISSING in Doppler (project: infrastructure, config: prd). Please add it in Doppler before deploying."
                        )

            # Valider statiquement (lors du Preview) que la clé existe dans Doppler
            pulumi.Output.all(
                self.doppler_secrets.map, req.name, req.remote_key, req.keys
            ).apply(_verify_keys)

            # Create ExternalSecret in the app's namespace
            es = k8s.apiextensions.CustomResource(
                f"secret-{app.name}-{req.name}",
                api_version="external-secrets.io/v1beta1",
                kind="ExternalSecret",
                metadata={
                    "name": req.name,
                    "namespace": app.namespace,
                    "annotations": {"pulumi.com/patchForce": "true"},
                },
                spec={
                    "refreshInterval": "1h",
                    "secretStoreRef": {
                        "kind": "ClusterSecretStore",
                        "name": "doppler",
                    },
                    "target": {"name": req.name, "creationPolicy": "Owner"},
                    "data": self._build_external_secret_data(req),
                },
                opts=local_opts,
            )
            secrets.append(es)
        return secrets
        # Register a listener to debug the output
        # secret.status.apply(lambda s: print(f"  [Registry] ExternalSecret {app.name}-{req.name} status: {s}"))

    def _setup_docker_secrets(
        self, app: AppModel, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        """
        Create a dockerhub-secret in the app's namespace for image pulling.
        This provides the '.dockerconfigjson' expected by Kubernetes.
        """
        # Create ExternalSecret for Docker Hub credentials
        # We reuse the same logic as _setup_secrets_for_app but with a fixed template
        es = k8s.apiextensions.CustomResource(
            f"dockerhub-secret-{app.name}",
            api_version="external-secrets.io/v1beta1",
            kind="ExternalSecret",
            metadata={
                "name": "dockerhub-secret",
                "namespace": app.namespace,
                "annotations": {"pulumi.com/patchForce": "true"},
            },
            spec={
                "refreshInterval": "1h",
                "secretStoreRef": {
                    "kind": "ClusterSecretStore",
                    "name": "doppler",
                },
                "target": {
                    "name": "dockerhub-secret",
                    "creationPolicy": "Owner",
                    "template": {
                        "type": "kubernetes.io/dockerconfigjson",
                        "data": {
                            ".dockerconfigjson": '{"auths":{"https://index.docker.io/v1/":{"username":"{{ .username | toString }}","password":"{{ .password | toString }}","auth":"{{ (print .username ":" .password) | b64enc }}"}}}'
                        },
                    },
                },
                "data": [
                    {"secretKey": "username", "remoteRef": {"key": "DOCKER_NAME"}},
                    {"secretKey": "password", "remoteRef": {"key": "DOCKER_HUB_TOKEN"}},
                ],
            },
            opts=opts,
        )
        return [es]

    def _build_external_secret_data(
        self, req: SecretRequirement
    ) -> List[Dict[str, Any]]:
        """Construct the data block for ExternalSecrets, supporting both flat keys and JSON properties."""
        data = []
        if isinstance(req.keys, dict):
            # Explicit mapping K8s Key -> Doppler Key
            for k8s_key, doppler_key in req.keys.items():
                if req.remote_key:
                    # Expecting Doppler Key is a property inside JSON
                    data.append(
                        {
                            "secretKey": k8s_key,
                            "remoteRef": {
                                "key": req.remote_key,
                                "property": doppler_key,
                            },
                        }
                    )
                else:
                    # Flat Doppler key
                    data.append(
                        {"secretKey": k8s_key, "remoteRef": {"key": doppler_key}}
                    )
        else:
            # List mapping
            for key in req.keys:
                if req.remote_key:
                    # The remote_key is a JSON block, the key is the property
                    data.append(
                        {
                            "secretKey": key,
                            "remoteRef": {"key": req.remote_key, "property": key},
                        }
                    )
                else:
                    # The K8s key and Doppler key are exactly the same (Flat)
                    data.append({"secretKey": key, "remoteRef": {"key": key}})
        return data

    def _setup_storage_for_app(
        self, app: AppModel, deployed_apps: Dict[str, Any], opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        """Provision PersistentVolumeClaims based on tiered storage model."""
        from shared.apps.common.storage_provisioner import StorageProvisionerFactory

        resources = []

        for idx, storage in enumerate(app.storage):
            if getattr(storage, "existing_claim", None):
                pulumi.Output.from_input(app.name).apply(
                    lambda name: print(
                        f"  [Registry] App {name} volume {idx} uses existing claim {storage.existing_claim}"
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
                    parent=self,
                    storagebox_manager=self.storagebox_manager,
                    setup_global_smb_callback=lambda: self._setup_hetzner_smb_resources(
                        deployed_apps, opts
                    ),
                )
            )
        return resources

    def _setup_database_for_app(
        self, app: AppModel, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        """Provision a local CNPG Cluster if requested in AppModel."""
        if not app.database or not app.database.local:
            return []

        print(f"  [Registry] Provisioning local CNPG Cluster for {app.name}...")

        # Determine storage class for DB
        # Default to local-path for DBs unless specified
        sc = app.database.storage_class or "local-path"

        db = k8s.apiextensions.CustomResource(
            f"db-{app.name}",
            api_version="postgresql.cnpg.io/v1",
            kind="Cluster",
            metadata={
                "name": f"{app.name}-db",
                "namespace": app.namespace,
                "labels": self._get_standard_labels(app),
            },
            spec={
                "instances": 2 if app.tier == "critical" else 1,
                "storage": {
                    "size": app.database.size,
                    "storageClass": sc,
                },
                "bootstrap": {
                    "initdb": {
                        "database": app.name,
                        "owner": app.name,
                    }
                },
            },
            opts=opts,
        )
        return [db]

    def _setup_hetzner_smb_resources(
        self,
        deployed_apps: Optional[Dict[str, Any]] = None,
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> List[pulumi.Resource]:
        """Provision global StorageClass and internal secrets for Hetzner SMB."""
        if self._hetzner_smb_ready:
            return []

        # Get credentials from config or env
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
            else pulumi.ResourceOptions(provider=self.provider, parent=self)
        )
        if deps:
            local_opts = pulumi.ResourceOptions.merge(
                local_opts, pulumi.ResourceOptions(depends_on=deps)
            )

        # 2. Register a global ExternalSecret in kube-system for the CSI driver to use
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

    def check_oci_storage_quota(self, apps: List[AppModel]):
        """
        Calculates total OCI storage usage and warns/errors if it exceeds the limit.
        Limit: 200GB (including boot volumes).
        """
        total_pvc_oci = 0
        for app in apps:
            for storage in app.storage:
                sc = storage.storage_class or "oci-bv"
                if sc == "oci-bv":
                    try:
                        size_str = storage.size.replace("Gi", "").replace("G", "")
                        total_pvc_oci += int(size_str)
                    except ValueError:
                        pass

        # Add CNPG Clusters (estimate)
        total_pvc_oci += 10  # Authentik DB (2 * 5Gi)

    def _setup_storagebox_automation(self):
        """
        Invoke the StorageBoxManager to provision sub-accounts via the Hetzner Cloud API.

        Required Pulumi config secrets:
            pulumi config set --secret hetzner:token <hcloud_api_token>

        Required Pulumi config:
            pulumi config set hetzner:storage_box_id 537179

        NOTE: The Storage Box must be visible in console.hetzner.cloud under
        your project. If you get a 404, confirm the box is listed there first.
        """
        pulumi_config = pulumi.Config("hetzner")
        storage_box_id = pulumi_config.get_int("storage_box_id") or self.config.get(
            "hcloud_storage_box_id"
        )

        identities = self.config.get("identities")
        if not identities:
            return

        # Handle both dict and object (Pydantic model)
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

    def _setup_identities(self):
        """Provision Authentik Users and Groups."""
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
                opts=pulumi.ResourceOptions(parent=self),
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
                opts=pulumi.ResourceOptions(parent=self),
            )

    def _setup_auth_for_app(
        self, app: AppModel, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        """Provision Authentik OAuth2 Providers and Applications for each app."""
        resources = []
        try:
            import pulumi_authentik as authentik
        except ImportError:
            return []

        if not app.auth:
            return []

        redirect_urls = [f"https://{app.hostname}/oauth2/callback"]
        if "freshrss" in app.name:
            redirect_urls.append(f"https://{app.hostname}/i/oidc/")

        if app.mode == ExposureMode.PROTECTED:
            provider = authentik.provider.proxy.ProxyProvider(
                f"proxy-provider-{app.name}",
                name=app.name,
                internal_host=f"http://{app.name}.{app.namespace}.svc.cluster.local:{app.port}",
                external_host=f"https://{app.hostname}",
                mode="forward_single",
                authorization_flow="default-provider-authorization-explicit-consent",
                opts=opts,
            )
        else:
            provider = authentik.provider.oauth2.OAuth2Provider(
                f"oauth2-provider-{app.name}",
                name=app.name,
                client_id=f"{app.name}-client",
                client_type="confidential",
                authorization_flow="default-provider-authorization-explicit-consent",
                redirect_uris="\n".join(redirect_urls),
                opts=opts,
            )
        resources.append(provider)

        appl = authentik.core.Application(
            f"auth-app-{app.name}",
            name=app.name.capitalize(),
            slug=app.name,
            provider=provider.id,
            meta_launch_url=f"https://{app.hostname}",
            opts=opts,
        )
        resources.append(appl)
        return resources

    def _setup_exposure_for_app(
        self, app: AppModel, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        """Create Ingress or Gateway routes based on app mode."""
        if getattr(app, "disable_auto_route", False):
            return []

        if app.mode == ExposureMode.PUBLIC:
            return self._create_gateway_route(app, opts)
        elif app.mode == ExposureMode.PROTECTED:
            return self._create_tunnel_ingress(app, opts)
        return []

    def _create_gateway_route(
        self, app: AppModel, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        """Creates an HTTPRoute via Envoy Gateway."""
        resources = []
        route = k8s.apiextensions.CustomResource(
            f"route-{app.name}",
            api_version="gateway.networking.k8s.io/v1",
            kind="HTTPRoute",
            metadata={
                "name": app.name,
                "namespace": app.namespace,
            },
            spec={
                "parentRefs": [
                    {"name": self.gateway_name, "namespace": self.gateway_namespace}
                ],
                "hostnames": [app.hostname],
                "rules": [
                    {
                        "backendRefs": [{"name": app.name, "port": app.port}],
                    }
                ],
            },
            opts=opts,
        )
        resources.append(route)

        if app.auth:
            sp = k8s.apiextensions.CustomResource(
                f"security-policy-{app.name}",
                api_version="gateway.envoyproxy.io/v1alpha1",
                kind="SecurityPolicy",
                metadata={
                    "name": app.name,
                    "namespace": app.namespace,
                },
                spec={
                    "targetRefs": [
                        {
                            "group": "gateway.networking.k8s.io",
                            "kind": "HTTPRoute",
                            "name": app.name,
                        }
                    ],
                    "extAuth": {
                        "http": {
                            "backendRefs": [
                                {
                                    "group": "",  # Core group
                                    "kind": "Service",
                                    "name": "authentik-server",
                                    "namespace": "authentik",
                                    "port": 80,
                                }
                            ]
                        }
                    },
                },
                opts=opts,
            )
            resources.append(sp)
        return resources

    def _create_tunnel_ingress(
        self, app: AppModel, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        """Creates a Cloudflare Tunnel Ingress."""
        ing = k8s.networking.v1.Ingress(
            f"tunnel-{app.name}",
            metadata={
                "name": app.name,
                "namespace": app.namespace,
                "annotations": {
                    "cloudflared.alpha.kubernetes.io/hostname": app.hostname,
                    "nginx.ingress.kubernetes.io/auth-url": "http://authentik-server.authentik.svc.cluster.local/outpost.goauthentik.io/auth/nginx",
                    "nginx.ingress.kubernetes.io/auth-signin": f"https://auth.{self.domain}/outpost.goauthentik.io/start?rd=$escaped_request_uri",
                    "nginx.ingress.kubernetes.io/auth-response-headers": "X-authentik-username,X-authentik-groups,X-authentik-email",
                }
                if app.auth
                else {
                    "cloudflared.alpha.kubernetes.io/hostname": app.hostname,
                },
            },
            spec={
                "ingressClassName": "cloudflared-tunnel",
                "rules": [
                    {
                        "host": app.hostname,
                        "http": {
                            "paths": [
                                {
                                    "path": "/",
                                    "pathType": "Prefix",
                                    "backend": {
                                        "service": {
                                            "name": app.name,
                                            "port": {"number": app.port},
                                        }
                                    },
                                }
                            ]
                        },
                    }
                ],
            },
            opts=opts,
        )
        return [ing]
