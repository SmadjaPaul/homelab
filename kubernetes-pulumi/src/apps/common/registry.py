"""
Unified Application Registry and Exposure Manager
"""

import pulumi
import pulumi_kubernetes as k8s
from typing import List, Dict, Any, Optional, Union
from enum import Enum
from utils.schemas import AppModel, SecretRequirement, StorageTier, ExposureMode, AppCategory, StorageAccess
from apps.common.storagebox import setup_storagebox_automation


# Note: ExposureMode and StorageTier are imported from utils.schemas


class AppRegistry(pulumi.ComponentResource):
    """
    Manages exposure (Public/Protected/Internal) and Secret requirements.
    """
    apps: List[AppModel]

    def __init__(
        self,
        name: str,
        provider: k8s.Provider,
        apps: List[Union[dict, AppModel]],
        config: Optional[Dict[str, Any]] = None,
        opts: Optional[pulumi.ResourceOptions] = None,
    ):
        super().__init__("homelab:common:AppRegistry", name, {}, opts)

        self.provider = provider
        self.config = config or {}
        self.domain = self.config.get("domain", "smadja.dev")
        self.gateway_name = self.config.get("gateway_name", "external")
        self.gateway_namespace = self.config.get("gateway_namespace", "envoy-gateway")

        # Convert potentially raw dicts to Pydantic models
        self.apps = [
            a if isinstance(a, AppModel) else AppModel.model_validate(a)
            for a in apps
        ]

        # 1. Process Secrets for all apps
        self._setup_secrets()

        # 2. Process RBAC (ServiceAccounts)
        self._setup_rbac()

        # 3. Process Reliability (PDBs)
        self._setup_reliability()

        # 4. Process Monitoring (ServiceMonitors)
        self._setup_monitoring()

        # 5. Process Storage (PVCs, Labels, Tiers)
        self._setup_storage()

        # 6. Process Authentik Identities (Users & Groups)
        self._setup_identities()

        # 7. Process Authentication (Authentik OIDC Providers/Apps)
        self._setup_auth()

        # 8. Process Exposure (Internal/Protected/Public)
        self._setup_exposure()

        # 9. Automate Hetzner Storage Box Sub-accounts
        self._setup_storagebox_automation()

        # 10. Hardware Quota Check (OCI 200GB limit)
        self._check_oci_storage_quota()

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

    def _setup_rbac(self):
        """Create a dedicated ServiceAccount for each app."""
        for app in self.apps:
            k8s.core.v1.ServiceAccount(
                f"sa-{app.name}",
                metadata={
                    "name": app.name,
                    "namespace": app.namespace,
                    "labels": self._get_standard_labels(app),
                },
                opts=pulumi.ResourceOptions(provider=self.provider, parent=self),
            )

    def _setup_reliability(self):
        """Create PodDisruptionBudget for apps with multiple replicas."""
        for app in self.apps:
            if app.replicas > 1:
                k8s.policy.v1.PodDisruptionBudget(
                    f"pdb-{app.name}",
                    metadata={
                        "name": app.name,
                        "namespace": app.namespace,
                        "labels": self._get_standard_labels(app),
                    },
                    spec={
                        "maxUnavailable": 1,
                        "selector": {
                            "matchLabels": {"app.kubernetes.io/name": app.name}
                        },
                    },
                    opts=pulumi.ResourceOptions(provider=self.provider, parent=self),
                )

    def _setup_monitoring(self):
        """Provision ServiceMonitor for Prometheus auto-discovery."""
        for app in self.apps:
            if not getattr(app, 'monitoring', True):
                continue

            k8s.apiextensions.CustomResource(
                f"servicemonitor-{app.name}",
                api_version="monitoring.coreos.com/v1",
                kind="ServiceMonitor",
                metadata={
                    "name": app.name,
                    "namespace": app.namespace,
                    "labels": {
                        **self._get_standard_labels(app),
                        "release": "prometheus-stack", # Common label for discovery
                    },
                },
                spec={
                    "selector": {
                        "matchLabels": {"app.kubernetes.io/name": app.name}
                    },
                    "endpoints": [
                        {
                            "port": "http", # Assumes service port name is 'http'
                            "path": "/metrics",
                            "interval": "30s",
                        }
                    ],
                },
                opts=pulumi.ResourceOptions(provider=self.provider, parent=self),
            )

    def _setup_secrets(self):
        """Provision ExternalSecrets for apps that require them."""
        for app in self.apps:
            for req in app.secrets:
                # Create ExternalSecret in the app's namespace
                k8s.apiextensions.CustomResource(
                    f"secret-{app.name}-{req.name}",
                    api_version="external-secrets.io/v1",
                    kind="ExternalSecret",
                    metadata={
                        "name": req.name,
                        "namespace": app.namespace,
                    },
                    spec={
                        "refreshInterval": "1h",
                        "secretStoreRef": {
                            "kind": "ClusterSecretStore",
                            "name": "doppler",
                        },
                        "target": {"name": req.name, "creationPolicy": "Owner"},
                        "data": [
                            {"secretKey": key, "remoteRef": {"key": req.remote_key or req.name, "property": key}}
                            for key in req.keys
                        ],
                    },
                    opts=pulumi.ResourceOptions(provider=self.provider, parent=self),
                )

    def _setup_storage(self):
        """Provision PersistentVolumeClaims based on tiered storage model."""
        from apps.common.storage_provisioner import StorageProvisionerFactory

        for app in self.apps:
            for idx, storage in enumerate(app.storage):
                if getattr(storage, 'existing_claim', None):
                    print(f"  [Registry] App {app.name} volume {idx} uses existing claim {storage.existing_claim}")
                    continue

                provisioner = StorageProvisionerFactory.get_provisioner(storage)
                provisioner.provision(
                    app=app,
                    storage=storage,
                    idx=idx,
                    provider=self.provider,
                    parent=self,
                    storagebox_manager=getattr(self, 'storagebox_manager', None),
                    setup_global_smb_callback=self._setup_hetzner_smb_resources
                )

    def _setup_hetzner_smb_resources(self):
        """Provision global StorageClass and internal secrets for Hetzner SMB."""
        if hasattr(self, "_hetzner_smb_ready"):
            return

        # Get credentials from config or env
        user = self.config.get("hetzner_smb_user", "your-username")
        url = self.config.get("hetzner_smb_url", f"//{user}.your-storagebox.de/backup")

        # 1. Create StorageClass
        k8s.storage.v1.StorageClass(
            "hetzner-smb-sc",
            metadata={
                "name": "hetzner-smb",
            },
            provisioner="smb.csi.k8s.io",
            parameters={
                "source": url,
                "csi.storage.k8s.io/provisioner-secret-name": "hetzner-storage-creds",
                "csi.storage.k8s.io/provisioner-secret-namespace": "kube-system",
                "csi.storage.k8s.io/node-stage-secret-name": "hetzner-storage-creds",
                "csi.storage.k8s.io/node-stage-secret-namespace": "kube-system",
            },
            mount_options=[
                "dir_mode=0777",
                "file_mode=0777",
                "uid=1000",
                "gid=1000",
                "noperm",
                "mfsymlinks",
                "cache=none",
            ],
            reclaim_policy="Retain",
            allow_volume_expansion=True,
            opts=pulumi.ResourceOptions(provider=self.provider, parent=self),
        )

        # 2. Register a global ExternalSecret in kube-system for the CSI driver to use
        k8s.apiextensions.CustomResource(
            "hetzner-storage-creds-global",
            api_version="external-secrets.io/v1",
            kind="ExternalSecret",
            metadata={
                "name": "hetzner-storage-creds",
                "namespace": "kube-system",
            },
            spec={
                "refreshInterval": "1h",
                "secretStoreRef": {
                    "kind": "ClusterSecretStore",
                    "name": "doppler",
                },
                "target": {"name": "hetzner-storage-creds", "creationPolicy": "Owner"},
                "data": [
                    {"secretKey": "username", "remoteRef": {"key": "HETZNER_STORAGE_BOX_1", "property": "username"}},
                    {"secretKey": "password", "remoteRef": {"key": "HETZNER_STORAGE_BOX_1", "property": "password"}},
                ],
            },
            opts=pulumi.ResourceOptions(provider=self.provider, parent=self),
        )

        self._hetzner_smb_ready = True

    def _check_oci_storage_quota(self):
        """
        Calculates total OCI storage usage and warns/errors if it exceeds the limit.
        Limit: 150GB (including boot volumes).
        """
        node_count = 2
        boot_vol_size = 50
        total_boot = node_count * boot_vol_size

        total_pvc_oci = 0
        for app in self.apps:
            for storage in app.storage:
                sc = storage.storage_class or "oci-bv"
                if sc == "oci-bv":
                    try:
                        size_str = storage.size.replace("Gi", "").replace("G", "")
                        total_pvc_oci += int(size_str)
                    except ValueError:
                        pass

        # Add CNPG Clusters (estimate)
        total_pvc_oci += 10 # Authentik DB (2 * 5Gi)

        grand_total = total_boot + total_pvc_oci
        print(f"  [Quota] OCI Usage: {total_boot}GB (Boot) + {total_pvc_oci}GB (Block) = {grand_total}GB")

        if grand_total > 200:
             print(f"  [Quota] WARNING: OCI Storage usage ({grand_total}GB) exceeds requested 200GB limit!")
        else:
             print(f"  [Quota] OCI Storage within limit: {grand_total}GB <= 200GB")

    def _setup_storagebox_automation(self):
        """Invoke the StorageBoxManager to provision sub-accounts."""
        storage_box_id = self.config.get("hcloud_storage_box_id")
        identities = self.config.get("identities")

        if not identities or not identities.users:
            self.storagebox_manager = None
            return

        self.storagebox_manager = setup_storagebox_automation(
            provider=self.provider,
            storage_box_id=storage_box_id,
            users=identities.users
        )

    def _setup_identities(self):
        """Provision Authentik Users and Groups."""
        identities = self.config.get("identities")
        if not identities or not hasattr(identities, 'users'):
            print("  [Registry] No valid identities configuration found, skipping SSO identities setup.")
            return

        try:
            import pulumi_authentik as authentik
        except ImportError:
            print("  [Registry] Warning: pulumi-authentik is not installed. Skipping SSO identities setup.")
            return

        print("  [Registry] Provisioning Authentik Groups and Users...")
        self.authentik_groups = {}
        for group in identities.groups:
            self.authentik_groups[group.name] = authentik.core.Group(
                f"auth-group-{group.name}",
                name=group.name,
                is_superuser=group.is_superuser,
                opts=pulumi.ResourceOptions(parent=self)
            )

        for user in identities.users:
            group_ids = [self.authentik_groups[g].id for g in user.groups if g in self.authentik_groups]
            authentik.core.User(
                f"auth-user-{user.name}",
                username=user.name,
                name=user.display_name or user.name,
                email=user.email,
                groups=group_ids,
                attributes=user.attributes,
                opts=pulumi.ResourceOptions(parent=self)
            )

    def _setup_auth(self):
        """Provision Authentik OAuth2 Providers and Applications for each app."""
        try:
            import pulumi_authentik as authentik
        except ImportError:
            print("  [Registry] Warning: pulumi-authentik is not installed. Skipping SSO app setup.")
            return

        for app in self.apps:
            if not app.auth:
                continue

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
                    opts=pulumi.ResourceOptions(parent=self),
                )
            else:
                provider = authentik.provider.oauth2.OAuth2Provider(
                    f"oauth2-provider-{app.name}",
                    name=app.name,
                    client_id=f"{app.name}-client",
                    client_type="confidential",
                    authorization_flow="default-provider-authorization-explicit-consent",
                    redirect_uris="\n".join(redirect_urls),
                    opts=pulumi.ResourceOptions(parent=self),
                )

            authentik.core.Application(
                f"auth-app-{app.name}",
                name=app.name.capitalize(),
                slug=app.name,
                provider=provider.id,
                meta_launch_url=f"https://{app.hostname}",
                opts=pulumi.ResourceOptions(parent=self)
            )

    def _setup_exposure(self):
        """Create Ingress or Gateway routes based on app mode."""
        for app in self.apps:
            if getattr(app, 'disable_auto_route', False):
                continue

            if app.mode == ExposureMode.PUBLIC:
                self._create_gateway_route(app)
            elif app.mode == ExposureMode.PROTECTED:
                self._create_tunnel_ingress(app)

    def _create_gateway_route(self, app: AppModel):
        """Creates an HTTPRoute via Envoy Gateway."""
        k8s.apiextensions.CustomResource(
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
                        "backendRefs": [
                            {"name": app.name, "port": app.port}
                        ],
                    }
                ],
            },
            opts=pulumi.ResourceOptions(provider=self.provider, parent=self),
        )

        if app.auth:
            k8s.apiextensions.CustomResource(
                f"security-policy-{app.name}",
                api_version="gateway.envoyproxy.io/v1alpha1",
                kind="SecurityPolicy",
                metadata={
                    "name": app.name,
                    "namespace": app.namespace,
                },
                spec={
                    "targetRefs": [{
                        "group": "gateway.networking.k8s.io",
                        "kind": "HTTPRoute",
                        "name": app.name,
                    }],
                    "extAuth": {
                        "http": {
                            "backendRef": {
                                "group": "",     # Core group
                                "kind": "Service",
                                "name": "authentik-server",
                                "namespace": "authentik",
                                "port": 80,
                            }
                        }
                    }
                },
                opts=pulumi.ResourceOptions(provider=self.provider, parent=self),
            )

    def _create_tunnel_ingress(self, app: AppModel):
        """Creates a Cloudflare Tunnel Ingress."""
        k8s.networking.v1.Ingress(
            f"tunnel-{app.name}",
            metadata={
                "name": app.name,
                "namespace": app.namespace,
                "annotations": {
                    "cloudflared.alpha.kubernetes.io/hostname": app.hostname,
                    "nginx.ingress.kubernetes.io/auth-url": f"http://authentik-server.authentik.svc.cluster.local/outpost.goauthentik.io/auth/nginx",
                    "nginx.ingress.kubernetes.io/auth-signin": f"https://auth.{self.domain}/outpost.goauthentik.io/start?rd=$escaped_request_uri",
                    "nginx.ingress.kubernetes.io/auth-response-headers": "X-authentik-username,X-authentik-groups,X-authentik-email",
                } if app.auth else {
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
            opts=pulumi.ResourceOptions(provider=self.provider, parent=self),
        )
