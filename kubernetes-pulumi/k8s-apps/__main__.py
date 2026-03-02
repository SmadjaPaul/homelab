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

# Get project root
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
apps_yaml_path = os.path.join(project_root, "apps.yaml")

import pulumi
from shared.apps.loader import AppLoader
from shared.apps.common.registry import AppRegistry
import pulumi_kubernetes as k8s
from shared.utils.cluster import get_kubeconfig, create_provider

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
full_config.update({
    "domain": domain,
    "cluster": cluster_filter,
})

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
infrastructure_apps = {'external-secrets', 'cert-manager', 'envoy-gateway', 'external-dns',
                       'cnpg-system', 'redis', 'local-path-provisioner', 'csi-driver-smb',
                       'cloudflared'}

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
             _ = core_operator_status.apply(lambda s: s and s.get("external-secrets") == "deployed")
        
        opts = pulumi.ResourceOptions(provider=provider)
        
        # 1. Register app in registry FIRST (to create secrets, PVCs, etc.)
        registry_resources = registry.register_app(app, deployed_apps, opts)
        
        # 2. Deploy via GenericHelmApp
        if app.helm and app.helm.chart:
            from shared.apps.generic import create_generic_app
            generic_app = create_generic_app(app)
            
            # Ensure deployment depends on registry resources
            if registry_resources:
                opts = pulumi.ResourceOptions.merge(opts, pulumi.ResourceOptions(depends_on=registry_resources))
            
            result = generic_app.deploy(
                provider,
                config=full_config,
                opts=opts
            )
            
            if result and "release" in result:
                deployed_apps[app_name] = result["release"]
            
            print(f"    {app_name}: deployed successfully")
        else:
            print(f"    {app_name}: no helm chart, skipping")
            
    except Exception as e:
        error_msg = f"  ERROR deploying {app_name}: {str(e)}"
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
