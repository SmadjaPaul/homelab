"""Homelab K8s Core Stack.

This stack provides the foundational infrastructure:
- Namespaces
- CRDs (CertManager, ExternalSecrets, EnvoyGateway, CNPG)
- Core Operators (cert-manager, external-secrets, envoy-gateway, external-dns)

Stack Outputs (exported for other stacks via StackReference):
- namespaces: dict of namespace names
- domain: the configured domain
- cluster_name: the target cluster
- operator_status: status of deployed operators
"""
import os
import pulumi
from shared.apps.loader import AppLoader
from shared.apps.factory import AppFactory
import pulumi_kubernetes as k8s
from shared.utils.cluster import get_kubeconfig, create_provider

config = pulumi.Config()
cluster_filter = config.get("cluster") or "oci"
domain = config.get("domain") or "smadja.dev"

# Get project root (parent of k8s-core, k8s-storage, k8s-apps)
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
apps_yaml_path = os.path.join(project_root, "apps.yaml")

# Stack name for StackReference
stack_name = pulumi.get_stack()
project_name = pulumi.get_project()

kubeconfig = get_kubeconfig()
provider = create_provider(cluster_filter, kubeconfig)

# Load essential infrastructure apps
loader = AppLoader(apps_yaml_path)
apps = loader.load_for_cluster(cluster_filter)
apps_by_name = {app.name: app for app in apps}

# 1. Namespaces creation
print("Phase 1: Creating namespaces...")
all_apps = loader.load()
unique_namespaces = {app.namespace for app in all_apps if app.namespace not in ["kube-system", "default"]}
namespaces = {}
namespace_list = []

for ns_name in unique_namespaces:
    ns = k8s.core.v1.Namespace(
        ns_name,
        metadata={"name": ns_name},
        opts=pulumi.ResourceOptions(provider=provider),
    )
    namespaces[ns_name] = ns
    namespace_list.append(ns_name)

print(f"  Created namespaces: {namespace_list}")

# 2. Core Operators Deployment
print("Phase 2: Deploying Core Operators...")
core_apps = ['external-secrets', 'cert-manager', 'envoy-gateway', 'external-dns']
deployed_apps = {}
operator_status = {}

full_config = loader.get_full_config()
full_config.update({
    "domain": domain,
})

for app_name in core_apps:
    app = apps_by_name.get(app_name)
    if not app:
        operator_status[app_name] = "not_configured"
        continue
        
    print(f"Deploying {app_name}...")
    
    # Deploy operators
    opts = pulumi.ResourceOptions(provider=provider)
    
    # Deploy Helm Chart
    if app.helm and app.helm.chart:
        try:
            # Use Factory to get specialized implementation (e.g. ExternalSecretsApp)
            generic_app = AppFactory.create(app)
            result = generic_app.deploy(provider, config=full_config, opts=opts)
            
            if "release" in result:
                deployed_apps[app_name] = result["release"]
                operator_status[app_name] = "deployed"
                print(f"  {app_name}: deployed")
            else:
                operator_status[app_name] = "skipped"
        except Exception as e:
            operator_status[app_name] = f"error: {str(e)}"
            print(f"  {app_name}: ERROR - {e}")

# =============================================================================
# EXPORTS - Available via StackReference for other stacks
# =============================================================================
pulumi.export("cluster_name", cluster_filter)
pulumi.export("domain", domain)
pulumi.export("stack_name", stack_name)
pulumi.export("project_name", project_name)

# Namespaces dict for other stacks to reference
pulumi.export("namespaces", namespaces)
pulumi.export("namespace_list", namespace_list)

# Operator status for other stacks to check dependencies
pulumi.export("operator_status", operator_status)

# Provider info (useful for debugging)
pulumi.export("provider_cluster", cluster_filter)
