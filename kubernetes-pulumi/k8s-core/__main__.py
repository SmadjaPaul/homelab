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
import pulumi_command as command
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
unique_namespaces = {
    app.namespace for app in all_apps if app.namespace not in ["kube-system", "default"]
}
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

# PriorityClasses for app tier management
k8s.scheduling.v1.PriorityClass(
    "homelab-critical",
    metadata=k8s.meta.v1.ObjectMetaArgs(name="homelab-critical"),
    value=1000,
    global_default=False,
    description="Critical homelab apps (authentik, vaultwarden)",
    opts=pulumi.ResourceOptions(provider=provider),
)

k8s.scheduling.v1.PriorityClass(
    "homelab-standard",
    metadata=k8s.meta.v1.ObjectMetaArgs(name="homelab-standard"),
    value=500,
    global_default=False,
    description="Standard homelab apps",
    opts=pulumi.ResourceOptions(provider=provider),
)

# 2. Core Operators Deployment
print("Phase 2: Deploying Core Operators...")
core_apps = ["external-secrets", "cert-manager", "envoy-gateway", "external-dns"]
deployed_apps = {}
operator_status = {}

full_config = loader.get_full_config()
full_config.update(
    {
        "domain": domain,
    }
)

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
# NODE PREPARATION - Install cifs-utils for SMB mounts
# =============================================================================
print("Phase 3: Node preparation (cifs-utils)...")

k8s.apps.v1.DaemonSet(
    "node-prep-cifs",
    metadata=k8s.meta.v1.ObjectMetaArgs(
        name="node-prep-cifs",
        namespace="kube-system",
        labels={"app.kubernetes.io/name": "node-prep-cifs"},
    ),
    spec=k8s.apps.v1.DaemonSetSpecArgs(
        selector=k8s.meta.v1.LabelSelectorArgs(
            match_labels={"app.kubernetes.io/name": "node-prep-cifs"},
        ),
        update_strategy=k8s.apps.v1.DaemonSetUpdateStrategyArgs(
            type="RollingUpdate",
        ),
        template=k8s.core.v1.PodTemplateSpecArgs(
            metadata=k8s.meta.v1.ObjectMetaArgs(
                labels={"app.kubernetes.io/name": "node-prep-cifs"},
            ),
            spec=k8s.core.v1.PodSpecArgs(
                host_network=True,
                host_pid=True,
                tolerations=[
                    k8s.core.v1.TolerationArgs(operator="Exists"),
                ],
                init_containers=[
                    k8s.core.v1.ContainerArgs(
                        name="install-cifs",
                        image="docker.io/library/alpine:3.20",
                        command=[
                            "nsenter",
                            "--target",
                            "1",
                            "--mount",
                            "--uts",
                            "--ipc",
                            "--net",
                            "--",
                            "sh",
                            "-c",
                        ],
                        args=[
                            "if ! command -v mount.cifs >/dev/null 2>&1; then "
                            "echo 'Installing cifs-utils...'; "
                            "yum install -y cifs-utils 2>/dev/null || dnf install -y cifs-utils 2>/dev/null || apt-get update && apt-get install -y cifs-utils 2>/dev/null || echo 'WARN: could not install cifs-utils'; "
                            "else echo 'cifs-utils already installed'; fi"
                        ],
                        security_context=k8s.core.v1.SecurityContextArgs(
                            privileged=True,
                        ),
                        resources=k8s.core.v1.ResourceRequirementsArgs(
                            limits={"cpu": "100m", "memory": "128Mi"},
                            requests={"cpu": "50m", "memory": "64Mi"},
                        ),
                    ),
                ],
                containers=[
                    k8s.core.v1.ContainerArgs(
                        name="pause",
                        image="registry.k8s.io/pause:3.10",
                        resources=k8s.core.v1.ResourceRequirementsArgs(
                            limits={"cpu": "10m", "memory": "16Mi"},
                            requests={"cpu": "1m", "memory": "4Mi"},
                        ),
                    ),
                ],
            ),
        ),
    ),
    opts=pulumi.ResourceOptions(provider=provider),
)
print("  node-prep-cifs DaemonSet deployed")

# =============================================================================
# HAIRPIN DNS FIX - CoreDNS rewrite rule for auth.smadja.dev
# =============================================================================
# Pods that call OIDC callbacks (Vaultwarden, OwnCloud, etc.) need to resolve
# auth.smadja.dev to the internal Authentik service, not the Cloudflare tunnel.
# This eliminates the need for hardcoded hostAliases in every pod.
print("Phase 4: Patching CoreDNS for hairpin DNS...")

_coredns_patch_script = r"""
python3 -c "
import subprocess, json, sys
try:
    cm_output = subprocess.check_output(
        ['kubectl', 'get', 'configmap', 'coredns', '-n', 'kube-system', '-o', 'json'],
        stderr=subprocess.DEVNULL
    )
    cm = json.loads(cm_output)
except Exception as e:
    print(f'CoreDNS ConfigMap not found or error: {e}')
    sys.exit(0)

corefile = cm.get('data', {}).get('Corefile', '')
rule = '    rewrite name auth.smadja.dev authentik-server.authentik.svc.cluster.local'
if rule in corefile:
    print('CoreDNS hairpin rule already present')
    sys.exit(0)

lines = corefile.split('\n')
inserted = False
for i, line in enumerate(lines):
    if line.strip() == 'ready':
        lines.insert(i + 1, rule)
        inserted = True
        break

if not inserted:
    print('Could not find ready directive in CoreDNS Corefile, skipping patch')
    sys.exit(0)

new_corefile = '\n'.join(lines)
patch_data = json.dumps({'data': {'Corefile': new_corefile}})
subprocess.run(
    ['kubectl', 'patch', 'configmap', 'coredns', '-n', 'kube-system',
     '--type', 'merge', '--patch', patch_data],
    check=True
)
subprocess.run(
    ['kubectl', 'rollout', 'restart', 'deployment/coredns', '-n', 'kube-system'],
    check=True
)
print('CoreDNS hairpin DNS rule applied and CoreDNS restarted')
"
"""

command.local.Command(
    "coredns-hairpin-patch",
    create=_coredns_patch_script,
    # Re-run only when this script changes (hash embedded in triggers)
    triggers=[1],
    opts=pulumi.ResourceOptions(),
)
print("  CoreDNS hairpin patch applied")

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
