"""
Pulumi Homelab - Simplified v2 Architecture

This version uses a data-driven approach:
- Apps are defined in apps.yaml
- GenericHelmApp handles Helm deployment automatically
- AppRegistry handles secrets, storage, auth, and routes
- Custom apps (like Kanidm) are implemented in Python
- Deployment order is determined by topological sort (dependencies first)
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

import pulumi
import pulumi_kubernetes as k8s

from utils.cluster import get_kubeconfig, create_provider

from apps.loader import get_loader, get_deployment_order
from apps.common.registry import AppRegistry


# Load configuration
config = pulumi.Config()
cluster_name = pulumi.get_stack()
domain = config.get("domain") or "smadja.dev"

# Create Kubernetes provider
kubeconfig = get_kubeconfig()
provider = create_provider(cluster_name, kubeconfig)

# Load apps from apps.yaml
loader = get_loader()

# Validate first
is_valid, error = loader.validate()
if not is_valid:
    raise ValueError(f"Apps.yaml validation failed: {error}")

# Get deployment order (topological sort - dependencies first)
deployment_order = loader.get_deployment_order(cluster_name)
print(f"Deployment order: {deployment_order}")

# Load apps and identities for cluster
apps = loader.load_for_cluster(cluster_name)
apps_by_name = {app.name: app for app in apps}
identities = loader.load_identities()

# Register apps (handles secrets, storage, auth, routes)
print("Setting up AppRegistry...")
full_config = loader.get_full_config()
full_config.update({
    "domain": domain,
    "gateway_name": "external",
    "gateway_namespace": "envoy-gateway",
    "identities": identities,
})

registry = AppRegistry(
    "homelab-registry",
    provider=provider,
    apps=apps,
    config=full_config,
)

# Deploy each app in order
for app_name in deployment_order:
    app = apps_by_name.get(app_name)
    if not app:
        continue

    print(f"Deploying {app_name}...")

    # Custom implementations or Generic Helm
    if app.chart:
        impl_module = None
        module_name = app.name.replace('-', '_')
        try:
            import importlib
            impl_module = importlib.import_module(f"apps.impl.{module_name}")
        except ImportError:
            pass

        if impl_module and hasattr(impl_module, "create_app"):
            print(f"  [Loader] Using custom implementation for {app_name}")
            custom_app = impl_module.create_app(app)
            custom_app.deploy(provider, {})
        else:
            # Generic Helm deployment
            from apps.generic import create_generic_app
            generic_app = create_generic_app(app)
            generic_app.deploy(provider, {})

pulumi.export("cluster_name", cluster_name)
pulumi.export("domain", domain)
