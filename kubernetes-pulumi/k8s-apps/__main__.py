"""Homelab K8s Apps Stack.

This stack deploys user applications:
- Authentik (identity provider & SSO)
- Homepage (dashboard)
- Nextcloud, Paperless-ngx (productivity)
- Navidrome, Slskd, Audiobookshelf (media)
- Vaultwarden (passwords)
- Open-WebUI (AI)

Deployment phases:
- Step 3a: K8s Resources (Secrets, PVCs, Helm releases)
- Step 3b: Authentik SSO (Proxy/OAuth2 providers, Outpost)
- Step 3c: Tunnel Configuration (Cloudflare Tunnel ingress rules)

DNS is managed by external-dns (auto-discovery from Authentik Outpost Ingress).

Stack Dependencies:
- k8s-core: Namespaces, operators (including external-dns)
- k8s-storage: Storage classes, databases, cache
"""

import os

import pulumi
import pulumiverse_doppler as doppler
from shared.apps.loader import AppLoader
from shared.apps.common.registry import AppRegistry
from shared.utils.cluster import get_kubeconfig, create_provider
from shared.utils.storage_validation import validate_storage_quota

# Get project root
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
apps_yaml_path = os.path.join(project_root, "apps.yaml")

# =============================================================================
# STACK REFERENCES & PROVIDERS
# =============================================================================
stack_name = pulumi.get_stack()

core_stack = pulumi.StackReference(f"organization/homelab-k8s-core/{stack_name}")
core_namespaces = core_stack.get_output("namespaces")
core_namespace_list = core_stack.get_output("namespace_list")
core_domain = core_stack.get_output("domain")
core_operator_status = core_stack.get_output("operator_status")

storage_stack = pulumi.StackReference(f"organization/homelab-k8s-storage/{stack_name}")
storage_classes = storage_stack.get_output("storage_classes")
database_endpoints = storage_stack.get_output("database_endpoints")
redis_endpoints = storage_stack.get_output("redis_endpoints")

config = pulumi.Config()
cluster_filter = config.get("cluster") or "oci"
domain = core_domain

kubeconfig = get_kubeconfig()
provider = create_provider(cluster_filter, kubeconfig)

# Load apps configuration
loader = AppLoader(apps_yaml_path)
apps = loader.load_for_cluster(cluster_filter)
apps_by_name = {app.name: app for app in apps}

deployment_order = loader.get_deployment_order(cluster_filter)
print(f"Stack: k8s-apps (cluster: {cluster_filter})")

# Security: Validate OCI Storage Quota
validate_storage_quota(apps)

full_config = loader.get_full_config()
full_config.update({"domain": domain, "cluster": cluster_filter})

# Doppler Configuration
doppler_config = pulumi.Config("homelab")
doppler_token = doppler_config.get_secret("dopplerToken") or config.get_secret(
    "dopplerToken"
)
doppler_provider = doppler.Provider("doppler-provider", doppler_token=doppler_token)

doppler_secrets = doppler.get_secrets_output(
    project="infrastructure",
    config="prd",
    opts=pulumi.InvokeOptions(provider=doppler_provider),
)

# =============================================================================
# PHASE 1: KUBERNETES DEPLOYMENT
# =============================================================================
print("\nPhase 1: Deploying Kubernetes Resources...")

# Populate Cloudflare config for TunnelManager
full_config.update(
    {
        "cloudflare_account_id": doppler_secrets.map["CLOUDFLARE_ACCOUNT_ID"],
        "cloudflare_tunnel_id": doppler_secrets.map["CLOUDFLARE_TUNNEL_ID"],
        "cloudflare_api_token": doppler_secrets.map["CLOUDFLARE_API_TOKEN"],
        "doppler_secrets": doppler_secrets.map,
    }
)

registry = AppRegistry(
    name="homelab-registry",
    provider=provider,
    config=full_config,
)
registry.setup_global_infrastructure()

# Apps that should NOT be deployed by this stack loop
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
helm_releases = {}
errors = []

for app_name in deployment_order:
    if app_name in infrastructure_apps:
        continue

    app = apps_by_name.get(app_name)
    if not app:
        continue

    print(f"  Deploying {app_name}...")
    try:
        opts = pulumi.ResourceOptions(provider=provider)

        # 1. Register app in registry (Secrets, PVCs, etc. - NO AUTHENTIK API CALLS YET)
        registry_resources = registry.register_app(app, deployed_apps, opts)

        # 2. Deploy via AppFactory
        if app.helm and app.helm.chart:
            from shared.apps.factory import AppFactory

            generic_app = AppFactory.create(app)

            if registry_resources:
                opts = pulumi.ResourceOptions.merge(
                    opts, pulumi.ResourceOptions(depends_on=registry_resources)
                )

            result = generic_app.deploy(provider, config=full_config, opts=opts)
            if result and "release" in result:
                deployed_apps[app_name] = True
                helm_releases[app_name] = result["release"]
            print(f"    {app_name}: deployed successfully")

    except Exception as e:
        error_msg = f"  ERROR deploying {app_name}: {str(e)}"
        print(error_msg)
        errors.append(error_msg)

# =============================================================================
# PHASE 2 & 3: AUTHENTIK CONFIGURATION
# =============================================================================
print("\nPhase 2: Configuring Authentik Identities & Applications...")
try:
    from shared.utils.authentik import create_authentik_provider

    # Authentik configuration
    auth_provider = create_authentik_provider(domain, provider)
    auth_resources = registry.configure_authentik_layer(
        apps, auth_provider, pulumi.ResourceOptions()
    )
    outpost_resources = registry.finalize_authentik_outpost(
        auth_provider, pulumi.ResourceOptions()
    )
    print(
        f"    Authentik configuration: completed successfully ({len(auth_resources) + len(outpost_resources)} resources)"
    )
except Exception as e:
    print(f"  ⚠️  Authentik configuration skipped/failed: {str(e)}")
    # We don't append to errors here to allow the stack to continue and fix DNS/Tunnel

# =============================================================================
# PHASE 4: TUNNEL CONFIGURATION
# =============================================================================
print("\nPhase 4: Configuring Tunnel (Cloudflare)...")
try:
    tunnel_resources = registry.setup_tunnel_layer(apps)
    print(
        f"    Tunnel configuration: completed successfully ({len(tunnel_resources)} resources)"
    )
except Exception as e:
    error_msg = f"  ERROR configuring Tunnel: {str(e)}"
    print(error_msg)
    errors.append(error_msg)

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
