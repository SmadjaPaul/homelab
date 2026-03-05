"""Homelab K8s Apps Stack.

This stack deploys user applications:
- Authentik (identity provider)
- Navidrome (music)
- Slskd (Soulseek)
- Vaultwarden (passwords)
- Homarr (dashboard)

Stack Dependencies:
- k8s-core: Namespaces, operators
- k8s-storage: Storage classes, databases, cache
"""

import os

import pulumi
from shared.apps.loader import AppLoader
from shared.apps.common.registry import AppRegistry
from shared.utils.cluster import get_kubeconfig, create_provider

# Get project root
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
apps_yaml_path = os.path.join(project_root, "apps.yaml")

# =============================================================================
# STACK REFERENCES - Import from k8s-core and k8s-storage
# =============================================================================
stack_name = pulumi.get_stack()

# Import from k8s-core
core_stack = pulumi.StackReference(f"organization/homelab-k8s-core/{stack_name}")
core_namespaces = core_stack.get_output("namespaces")
core_namespace_list = core_stack.get_output("namespace_list")
core_domain = core_stack.get_output("domain")
core_operator_status = core_stack.get_output("operator_status")

# Import from k8s-storage
storage_stack = pulumi.StackReference(f"organization/homelab-k8s-storage/{stack_name}")
storage_classes = storage_stack.get_output("storage_classes")
database_endpoints = storage_stack.get_output("database_endpoints")
redis_endpoints = storage_stack.get_output("redis_endpoints")

config = pulumi.Config()
cluster_filter = config.get("cluster") or "oci"

kubeconfig = get_kubeconfig()
provider = create_provider(cluster_filter, kubeconfig)

# Load apps configuration
loader = AppLoader(apps_yaml_path)
apps = loader.load_for_cluster(cluster_filter)
apps_by_name = {app.name: app for app in apps}

# Get domain from core stack
domain = core_domain

print(f"Stack: k8s-apps (cluster: {cluster_filter})")

# Full config with all merged values
full_config = loader.get_full_config()
full_config.update(
    {
        "domain": domain,
        "cluster": cluster_filter,
    }
)

# =============================================================================
# APP REGISTRY - Setup cross-cutting concerns
# =============================================================================
print("\nPhase 1: Setting up AppRegistry...")
registry = AppRegistry(
    name="homelab-registry",
    provider=provider,
    config=full_config,
)
registry.setup_global_infrastructure()

# =============================================================================
# DEPLOY APPLICATIONS
# =============================================================================
# Get deployment order from loader
deployment_order = loader.get_deployment_order(cluster_filter)
print(f"\nPhase 2: Deploying {len(deployment_order)} applications...")
print(f"  Deployment order: {deployment_order}")

# Apps that should be deployed by this stack (not infrastructure)
# Exclude core operators (deployed in k8s-core) and storage (deployed in k8s-storage)
infrastructure_apps = {
    "external-secrets",
    "cert-manager",
    "envoy-gateway",
    "external-dns",
    "cnpg-system",
    "redis",
    "local-path-provisioner",
    "csi-driver-smb",
    "cloudflared",
}

deployed_apps = {}
errors = []

for app_name in deployment_order:
    # Skip infrastructure apps - they're deployed in other stacks
    if app_name in infrastructure_apps:
        print(f"  Skipping {app_name} (deployed in other stack)")
        continue

    app = apps_by_name.get(app_name)
    if not app:
        continue

    print(f"  Deploying {app_name}...")

    try:
        # If the app has secrets, ensure external-secrets status is at least imported
        # to avoid the crashes we saw earlier with Output.apply on None
        if app.secrets:
            _ = core_operator_status.apply(
                lambda s: s and s.get("external-secrets") == "deployed"
            )

        opts = pulumi.ResourceOptions(provider=provider)

        # 1. Register app in registry FIRST (to create secrets, PVCs, etc.)
        registry_resources = registry.register_app(app, deployed_apps, opts)

        # 2. Deploy via AppFactory (supports specialized subclasses)
        if app.helm and app.helm.chart:
            from shared.apps.factory import AppFactory

            generic_app = AppFactory.create(app)

            # Ensure deployment depends on registry resources
            if registry_resources:
                opts = pulumi.ResourceOptions.merge(
                    opts, pulumi.ResourceOptions(depends_on=registry_resources)
                )

            result = generic_app.deploy(provider, config=full_config, opts=opts)

            if result and "release" in result:
                # Store a simple boolean to indicate deployment success in this run
                # Avoid storing the full Output[Release] object to prevent serialization issues
                deployed_apps[app_name] = True

            print(f"    {app_name}: deployed successfully")
        else:
            print(f"    {app_name}: no helm chart, skipping")

    except Exception as e:
        error_msg = f"  ERROR deploying {app_name}: {str(e)}"
        print(error_msg)
        errors.append(error_msg)

# =============================================================================
# PHASE 3 — Finalize Authentik Outpost
# =============================================================================
print("\nPhase 3: Finalizing Authentik Outpost...")
registry.finalize_authentik_outpost()

# =============================================================================
# PHASE 4 — Configure Cloudflare Tunnel ingress rules (from apps.yaml)
# =============================================================================
if "cloudflared" in apps_by_name:
    print("\nPhase 4: Configuring Cloudflare Tunnel routes...")
    import pulumi_cloudflare as cloudflare
    import pulumiverse_doppler as doppler

    doppler_secrets = doppler.get_secrets_output(project="infrastructure", config="prd")
    cf_account_id = doppler_secrets.map.apply(
        lambda m: m.get("CLOUDFLARE_ACCOUNT_ID", "")
    )
    cf_tunnel_id = doppler_secrets.map.apply(
        lambda m: m.get("CLOUDFLARE_TUNNEL_ID", "")
    )
    cf_api_token = doppler_secrets.map.apply(
        lambda m: m.get("CLOUDFLARE_API_TOKEN", "")
    )

    cf_provider = cloudflare.Provider("cloudflare-provider", api_token=cf_api_token)

    # Build ingress rules dynamically from exposed apps
    exposed_apps = [
        a for a in apps if a.hostname and a.mode.value in ("public", "protected")
    ]

    ingress_rules = []

    # Static routes for infrastructure services
    static_routes = [
        ("auth", "http://authentik-server.authentik.svc.cluster.local:80"),
        ("login", "http://authentik-server.authentik.svc.cluster.local:80"),
    ]
    for subdomain, service in static_routes:
        ingress_rules.append(
            cloudflare.ZeroTrustTunnelCloudflaredConfigConfigIngressRuleArgs(
                hostname=f"{subdomain}.{full_config.get('domain', 'smadja.dev')}",
                service=service,
                origin_request=cloudflare.ZeroTrustTunnelCloudflaredConfigConfigIngressRuleOriginRequestArgs(
                    no_tls_verify=True,
                    connect_timeout="30s",
                ),
            )
        )

    # Dynamic routes from apps.yaml
    for app in exposed_apps:
        if app.mode.value == "protected":
            # Route through Authentik Outpost Proxy (handles auth + proxies to backend)
            svc_url = "http://ak-outpost-authentik-embedded-outpost.authentik.svc.cluster.local:9000"
        else:
            # Route directly to the app service
            svc_name = "authentik-server" if app.name == "authentik" else app.name
            svc_url = f"http://{svc_name}.{app.namespace}.svc.cluster.local:{app.port}"

        ingress_rules.append(
            cloudflare.ZeroTrustTunnelCloudflaredConfigConfigIngressRuleArgs(
                hostname=app.hostname,
                service=svc_url,
                origin_request=cloudflare.ZeroTrustTunnelCloudflaredConfigConfigIngressRuleOriginRequestArgs(
                    no_tls_verify=True,
                    connect_timeout="30s",
                ),
            )
        )
        print(f"  Route: {app.hostname} → {svc_url}")

    # Catch-all fallback (required by Cloudflare)
    ingress_rules.append(
        cloudflare.ZeroTrustTunnelCloudflaredConfigConfigIngressRuleArgs(
            service="http_status:404",
        )
    )

    # Apply the tunnel configuration
    cloudflare.ZeroTrustTunnelCloudflaredConfig(
        "homelab-tunnel-config",
        account_id=cf_account_id,
        tunnel_id=cf_tunnel_id,
        config=cloudflare.ZeroTrustTunnelCloudflaredConfigConfigArgs(
            ingress_rules=ingress_rules,
        ),
        opts=pulumi.ResourceOptions(provider=cf_provider),
    )
    print(f"  Total routes: {len(ingress_rules)} (including catch-all)")

# =============================================================================
# EXPORTS
# =============================================================================
pulumi.export("cluster_name", cluster_filter)
pulumi.export("domain", domain)
pulumi.export("deployed_apps", list(deployed_apps.keys()))
pulumi.export("app_count", len(deployed_apps))

if errors:
    print(f"\n⚠️  Deployment completed with {len(errors)} errors:")
    for err in errors:
        print(f"  - {err}")
else:
    print(f"\n✅ All {len(deployed_apps)} applications deployed successfully!")
