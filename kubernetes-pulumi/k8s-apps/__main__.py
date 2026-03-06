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
import pulumi_cloudflare as cloudflare
import pulumiverse_doppler as doppler
from shared.apps.loader import AppLoader
from shared.apps.common.registry import AppRegistry
from shared.utils.cluster import get_kubeconfig, create_provider

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
# PHASE 2: AUTHENTIK API CONFIGURATION
# =============================================================================
authentik_release = helm_releases.get("authentik")
if "authentik" in apps_by_name and authentik_release:
    print("\nPhase 2: Configuring Authentik API Layer...")
    try:
        import pulumi_authentik as authentik

        # 2.1 Initialize Authentik Provider ONLY IF the helm release exists
        ak_token = doppler_secrets.map.apply(
            lambda m: m.get("AUTHENTIK_BOOTSTRAP_TOKEN", "")
        )
        # We explicitly assemble the URL using the domain string to avoid race conditions
        ak_url = domain.apply(lambda d: f"https://auth.{d}")

        # IMPORTANT: Provider depends on the helm release being completely finished
        authentik_provider = authentik.Provider(
            "authentik-provider",
            token=ak_token,
            url=ak_url,
            opts=pulumi.ResourceOptions(depends_on=[authentik_release]),
        )

        # 2.2 Configure Proxies & Applications
        # Using depends_on to ensure provider connects only after cluster deployment
        ak_opts = pulumi.ResourceOptions(depends_on=[authentik_release])
        ak_resources = registry.configure_authentik_layer(
            apps, authentik_provider, ak_opts
        )

        # 2.3 Create the Outpost
        # Outpost depends on all proxy/app configurations being done
        op_opts = pulumi.ResourceOptions.merge(
            ak_opts, pulumi.ResourceOptions(depends_on=ak_resources)
        )
        outpost_resources = registry.finalize_authentik_outpost(
            authentik_provider, opts=op_opts
        )

    except ImportError:
        print("  pulumi_authentik not found! Skipping API config.")
        outpost_resources = []
else:
    print("\nPhase 2: Authentik not deployed or enabled, skipping API config.")
    outpost_resources = []

# =============================================================================
# PHASE 3: CLOUDFLARE TUNNEL & DNS ROUTING
# =============================================================================
if "cloudflared" in apps_by_name:
    print("\nPhase 3: Configuring Cloudflare Routing...")
    cf_account_id = doppler_secrets.map.apply(
        lambda m: m.get("CLOUDFLARE_ACCOUNT_ID", "")
    )
    cf_tunnel_id = doppler_secrets.map.apply(
        lambda m: m.get("CLOUDFLARE_TUNNEL_ID", "")
    )
    cf_zone_id = doppler_secrets.map.apply(lambda m: m.get("CLOUDFLARE_ZONE_ID", ""))
    cf_api_token = doppler_secrets.map.apply(
        lambda m: m.get("CLOUDFLARE_API_TOKEN", "")
    )

    cf_provider = cloudflare.Provider("cloudflare-provider", api_token=cf_api_token)
    tunnel_cname_target = cf_tunnel_id.apply(lambda tid: f"{tid}.cfargotunnel.com")

    # IMPORTANT: Tunnel routes should only be considered ready IF the outpost has been configured!
    cf_opts = pulumi.ResourceOptions(provider=cf_provider, depends_on=outpost_resources)

    exposed_apps = [
        a for a in apps if a.hostname and a.mode.value in ("public", "protected")
    ]
    ingress_rules = []
    all_dns_records = []

    static_routes = [
        ("login", "http://authentik-server.authentik.svc.cluster.local:80")
    ]

    for subdomain, service in static_routes:
        hostname = domain.apply(lambda d: f"{subdomain}.{d}")
        ingress_rules.append(
            cloudflare.ZeroTrustTunnelCloudflaredConfigConfigIngressArgs(
                hostname=hostname,
                service=service,
                origin_request=cloudflare.ZeroTrustTunnelCloudflaredConfigConfigIngressOriginRequestArgs(
                    no_tls_verify=True,
                    connect_timeout=30,
                ),
            )
        )
        all_dns_records.append(
            cloudflare.DnsRecord(
                f"dns-record-{subdomain}",
                name=subdomain,
                zone_id=cf_zone_id,
                type="CNAME",
                content=tunnel_cname_target,
                proxied=True,
                ttl=1,
                opts=cf_opts,
            )
        )

    for app in exposed_apps:
        if app.mode.value == "protected":
            svc_url = "http://ak-outpost-authentik-embedded-outpost.authentik.svc.cluster.local:9000"
        else:
            svc_name = "authentik-server" if app.name == "authentik" else app.name
            svc_url = f"http://{svc_name}.{app.namespace}.svc.cluster.local:{app.port}"

        ingress_rules.append(
            cloudflare.ZeroTrustTunnelCloudflaredConfigConfigIngressArgs(
                hostname=app.hostname,
                service=svc_url,
                origin_request=cloudflare.ZeroTrustTunnelCloudflaredConfigConfigIngressOriginRequestArgs(
                    no_tls_verify=True,
                    connect_timeout=30,
                ),
            )
        )
        all_dns_records.append(
            cloudflare.DnsRecord(
                f"dns-record-{app.name}",
                name=app.hostname,
                zone_id=cf_zone_id,
                type="CNAME",
                content=tunnel_cname_target,
                proxied=True,
                ttl=1,
                opts=cf_opts,
            )
        )

    ingress_rules.append(
        cloudflare.ZeroTrustTunnelCloudflaredConfigConfigIngressArgs(
            service="http_status:404"
        )
    )

    # === Mail DNS Migration ===
    print("  [DNS] Implementing Migadu Mail DNS records...")
    from shared.networking.cloudflare.mail_dns import MailDnsManager

    MailDnsManager(
        "migadu-mail-dns",
        domain=domain,
        zone_id=cf_zone_id,
        cf_opts=cf_opts,
    )

    tunnel_config = cloudflare.ZeroTrustTunnelCloudflaredConfig(
        "homelab-tunnel-config",
        account_id=cf_account_id,
        tunnel_id=cf_tunnel_id,
        config=cloudflare.ZeroTrustTunnelCloudflaredConfigConfigArgs(
            ingresses=ingress_rules
        ),
        opts=cf_opts,
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
