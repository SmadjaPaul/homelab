# Implementation Plan — Authentik Proxy Auth + CF Tunnel Migration

## Problem Statement

Protected applications (`mode: protected`) are accessible **without authentication**. The forward auth chain is not in place because:

1. No Authentik **Proxy Outpost** is deployed in the cluster
2. Cloudflare Tunnel routes traffic **directly to apps**, bypassing Authentik
3. `_setup_auth_for_app()` creates a `ProxyProvider` with `forward_single` mode (requires a reverse proxy like nginx/traefik — incompatible with CF Tunnel alone)
4. The old `pulumi_authentik` API (`authentik.provider.proxy.ProxyProvider`, `authentik.core.Application`) is used instead of the current one (`authentik.ProviderProxy`, `authentik.Application`)

### Target Architecture

```
Internet → Cloudflare Tunnel → Authentik Outpost (:9000) → Backend App
                                    ↕
                              Authentik Server
                              (auth flows, sessions)
```

---

## Changes Required

### 1. `apps.yaml` — Enable `auth: true` on protected apps

**File**: `kubernetes-pulumi/apps.yaml`

Add `auth: true` to each app with `mode: protected`:

```yaml
  - name: navidrome
    mode: protected
    auth: true          # ADD THIS
    ...

  - name: vaultwarden
    mode: protected
    auth: true          # ADD THIS
    ...
```

Both apps already have `authentik` in their `dependencies` list — no change needed there.

---

### 2. `schemas.py` — Auto-derive `auth` from `mode: protected`

**File**: `kubernetes-pulumi/shared/utils/schemas.py`

Add a `@model_validator` to `AppModel` that automatically sets `auth = True` when `mode == ExposureMode.PROTECTED`. This prevents the common mistake of setting `mode: protected` without `auth: true`.

Insert **before** the existing `validate_image_registries` validator (line ~187):

```python
@model_validator(mode="after")
def auto_enable_auth_for_protected(self) -> "AppModel":
    """Automatically enable auth proxy when mode is protected."""
    if self.mode == ExposureMode.PROTECTED and not self.auth:
        self.auth = True
    return self
```

---

### 3. `registry.py` — Remove dead code (~113 lines)

**File**: `kubernetes-pulumi/shared/apps/common/registry.py`

#### 3a. Remove unused attributes from `__init__` (line ~38-39)

Delete these two lines:
```python
self.gateway_name = self.config.get("gateway_name", "external")
self.gateway_namespace = self.config.get("gateway_namespace", "envoy-gateway")
```

Add this line instead:
```python
self._proxy_provider_ids: list = []  # Collected for outpost binding
```

#### 3b. Replace `_setup_exposure_for_app` and its helpers (lines ~613-725)

Delete the following methods entirely:
- `_setup_exposure_for_app()` (lines 613-622)
- `_create_gateway_route()` (lines 624-682)
- `_create_tunnel_ingress()` (lines 684-725)

Replace with a no-op stub:
```python
def _setup_exposure_for_app(self, app: AppModel, opts: pulumi.ResourceOptions) -> List[pulumi.Resource]:
    """Exposure is managed centrally via ZeroTrustTunnelCloudflaredConfig in k8s-apps.

    All apps with a hostname are automatically routed through the Cloudflare Tunnel.
    No per-app HTTPRoute or Ingress resources are needed.
    """
    return []
```

---

### 4. `registry.py` — Fix `_setup_auth_for_app` (lines ~565-611)

**File**: `kubernetes-pulumi/shared/apps/common/registry.py`

Replace the entire method with:

```python
def _setup_auth_for_app(self, app: AppModel, opts: pulumi.ResourceOptions) -> List[pulumi.Resource]:
    """Provision Authentik Proxy or OAuth2 Providers and Applications for each app."""
    resources = []
    try:
        import pulumi_authentik as authentik
    except ImportError:
        return []

    if not app.auth:
        return []

    if app.mode == ExposureMode.PROTECTED:
        # Proxy mode: outpost intercepts traffic and proxies to the backend
        provider = authentik.ProviderProxy(
            f"proxy-provider-{app.name}",
            name=app.name,
            internal_host=f"http://{app.name}.{app.namespace}.svc.cluster.local:{app.port}",
            external_host=f"https://{app.hostname}",
            mode="proxy",
            authorization_flow="default-provider-authorization-explicit-consent",
            invalidation_flow="default-provider-invalidation-flow",
            opts=opts,
        )
        # Collect provider ID for outpost binding (done in finalize_authentik_outpost)
        self._proxy_provider_ids.append(provider.id)
    else:
        # Standard OIDC for public apps with auth
        redirect_urls = [f"https://{app.hostname}/oauth2/callback"]
        provider = authentik.ProviderOauth2(
            f"oauth2-provider-{app.name}",
            name=app.name,
            client_id=f"{app.name}-client",
            client_type="confidential",
            authorization_flow="default-provider-authorization-explicit-consent",
            invalidation_flow="default-provider-invalidation-flow",
            allowed_redirect_uris="\n".join(redirect_urls),
            opts=opts,
        )
    resources.append(provider)

    appl = authentik.Application(
        f"auth-app-{app.name}",
        name=app.name.capitalize(),
        slug=app.name,
        protocol_provider=provider.id,
        meta_launch_url=f"https://{app.hostname}",
        opts=opts,
    )
    resources.append(appl)
    return resources
```

Key changes from the original:
- `authentik.provider.proxy.ProxyProvider` → `authentik.ProviderProxy`
- `authentik.provider.oauth2.OAuth2Provider` → `authentik.ProviderOauth2`
- `authentik.core.Application` → `authentik.Application`
- `provider=provider.id` → `protocol_provider=provider.id`
- `redirect_uris` → `allowed_redirect_uris`
- Added `invalidation_flow` parameter (required)
- Changed mode from `"forward_single"` to `"proxy"`
- Added `self._proxy_provider_ids.append(provider.id)` for outpost binding

---

### 5. `registry.py` — Add `finalize_authentik_outpost()` method

**File**: `kubernetes-pulumi/shared/apps/common/registry.py`

Add this method to `AppRegistry`, after `setup_global_infrastructure()`:

```python
def finalize_authentik_outpost(self):
    """Create the Authentik Outpost after all apps have been registered.

    Must be called AFTER all register_app() calls so that all proxy
    provider IDs have been collected.
    """
    if not self._proxy_provider_ids:
        print("  [Registry] No proxy providers found, skipping outpost creation.")
        return

    try:
        import pulumi_authentik as authentik
    except ImportError:
        print("  [Registry] pulumi_authentik not installed, skipping outpost.")
        return

    print(f"  [Registry] Creating Authentik Outpost with {len(self._proxy_provider_ids)} providers...")

    # Kubernetes service connection — uses the Authentik pod's own service account
    svc_conn = authentik.ServiceConnectionKubernetes(
        "authentik-k8s-connection",
        name="Local Kubernetes",
        local=True,
        opts=pulumi.ResourceOptions(parent=self),
    )

    import json
    authentik.Outpost(
        "authentik-embedded-outpost",
        name="authentik-embedded-outpost",
        type="proxy",
        service_connection=svc_conn.id,
        protocol_providers=self._proxy_provider_ids,
        config=json.dumps({
            "authentik_host": f"https://auth.{self.domain}",
            "kubernetes_namespace": "authentik",
        }),
        opts=pulumi.ResourceOptions(parent=self),
    )
    print("  [Registry] Authentik Outpost created.")
```

The outpost will auto-deploy a pod `ak-outpost-authentik-embedded-outpost` in the `authentik` namespace, exposing port 9000 (HTTP) and 9443 (HTTPS).

The resulting K8s service will be:
`ak-outpost-authentik-embedded-outpost.authentik.svc.cluster.local:9000`

---

### 6. `k8s-apps/__main__.py` — Call outpost finalization + CF tunnel config

**File**: `kubernetes-pulumi/k8s-apps/__main__.py`

#### 6a. Call `finalize_authentik_outpost()` after the deploy loop

Insert after the deployment `for` loop (around line 157), before the EXPORTS section:

```python
# =============================================================================
# FINALIZE — Create Authentik Outpost with all collected proxy providers
# =============================================================================
print("\nPhase 3: Finalizing Authentik Outpost...")
registry.finalize_authentik_outpost()
```

#### 6b. Add Phase 4 — Dynamic Cloudflare Tunnel Config

Insert after the outpost finalization, before EXPORTS:

```python
# =============================================================================
# PHASE 4 — Configure Cloudflare Tunnel ingress rules (from apps.yaml)
# =============================================================================
if "cloudflared" in apps_by_name:
    print("\nPhase 4: Configuring Cloudflare Tunnel routes...")
    import pulumi_cloudflare as cloudflare
    import pulumiverse_doppler as doppler

    doppler_secrets = doppler.get_secrets_output(project="infrastructure", config="prd")
    cf_account_id = doppler_secrets.map.apply(lambda m: m.get("CLOUDFLARE_ACCOUNT_ID", ""))
    cf_tunnel_id = doppler_secrets.map.apply(lambda m: m.get("CLOUDFLARE_TUNNEL_ID", ""))
    cf_api_token = doppler_secrets.map.apply(lambda m: m.get("CLOUDFLARE_API_TOKEN", ""))

    cf_provider = cloudflare.Provider("cloudflare-provider", api_token=cf_api_token)

    # Build ingress rules dynamically from exposed apps
    exposed_apps = [a for a in apps if a.hostname and a.mode.value in ("public", "protected")]

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
```

**Note**: `pulumi-cloudflare` is already in `pyproject.toml`. The Doppler secrets `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_TUNNEL_ID`, `CLOUDFLARE_API_TOKEN` are already provisioned.

---

### 7. Terraform — Remove tunnel config block

**File**: `terraform/cloudflare/modules/tunnel/main.tf`

Remove the entire `cloudflare_zero_trust_tunnel_cloudflared_config` resource block (lines 56-102). Replace with a comment:

```hcl
# NOTE: Tunnel ingress config (cloudflare_zero_trust_tunnel_cloudflared_config)
# has been migrated to Pulumi (k8s-apps stack) where it is generated dynamically
# from apps.yaml. This keeps apps.yaml as the single source of truth for routing.
```

Keep the tunnel resource itself (`cloudflare_zero_trust_tunnel_cloudflared` at lines 18-28) and all outputs (tunnel_id, tunnel_name, tunnel_token, cname_target).

**Important**: After removing this resource, you must run `terraform state rm 'module.tunnel[0].cloudflare_zero_trust_tunnel_cloudflared_config.homelab[0]'` to avoid Terraform trying to destroy the existing config on the next apply. Pulumi will take ownership.

---

### 8. Tests to Add/Update

#### 8a. `tests/integration/test_app_dependencies.py` — Protected apps depend on authentik

```python
def test_protected_apps_depend_on_authentik():
    """Apps with mode=protected must have 'authentik' in dependencies."""
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    loader = AppLoader(os.path.join(project_root, "apps.yaml"))
    for cluster in ["oci", "local"]:
        apps = loader.load_for_cluster(cluster)
        for app in apps:
            if app.name in ["authentik", "kube-system", "external-secrets"]:
                continue
            if app.mode == ExposureMode.PROTECTED:
                assert "authentik" in app.dependencies, \
                    f"App '{app.name}' is protected but missing 'authentik' dependency"
```

#### 8b. `tests/static/test_cloudflare_routing.py` — NEW file

```python
"""Verify that CF tunnel routing follows the correct pattern for each app mode."""
import os, pytest
from shared.apps.loader import AppLoader
from shared.utils.schemas import ExposureMode

OUTPOST_SVC = "ak-outpost-authentik-embedded-outpost.authentik.svc.cluster.local:9000"

def get_apps():
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    return AppLoader(os.path.join(project_root, "apps.yaml")).load_for_cluster("oci")

def build_svc_url(app):
    """Replicate the routing logic from k8s-apps/__main__.py."""
    if app.mode == ExposureMode.PROTECTED:
        return f"http://{OUTPOST_SVC}"
    svc_name = "authentik-server" if app.name == "authentik" else app.name
    return f"http://{svc_name}.{app.namespace}.svc.cluster.local:{app.port}"

@pytest.mark.parametrize("app", [a for a in get_apps() if a.hostname and a.mode.value in ("public", "protected")])
def test_protected_apps_route_to_outpost(app):
    """Protected apps must route through the Authentik outpost, not directly."""
    svc_url = build_svc_url(app)
    if app.mode == ExposureMode.PROTECTED:
        assert "outpost" in svc_url, \
            f"Protected app {app.name} routes to {svc_url} instead of outpost"
    else:
        assert "outpost" not in svc_url, \
            f"Public app {app.name} should NOT route through outpost"
```

#### 8c. `tests/integration/test_connectivity.py` — Enforce redirect (not warning)

Change line ~46-51 from:

```python
# Current: just prints a warning if no redirect
if "authentik" in response.url or response.status_code in [302, 401]:
    print(f"    [INFO] {app.name} is correctly protected by Authentik")
else:
    print(f"    [WARNING] ...")
```

To:

```python
# Enforce: protected apps MUST redirect to authentik
assert "authentik" in response.url or response.status_code in [302, 401], \
    f"Protected app {app.name} is accessible WITHOUT auth (status {response.status_code}, url {response.url})"
```

#### 8d. `tests/test_registry_v2.py` — Verify proxy provider IDs are collected

Update `test_authentik_proxy_provider_for_protected_apps` (line ~82) to verify that `_proxy_provider_ids` is populated after registration.

---

## Execution Order

| Step | Risk | What to do |
|------|------|------------|
| 1 | None | `apps.yaml`: add `auth: true` |
| 2 | None | `schemas.py`: add auto-detect validator |
| 3 | None | `registry.py`: remove dead code (L613-725 + init attrs) |
| 4 | Medium | `registry.py`: fix `_setup_auth_for_app` |
| 5 | Medium | `registry.py`: add `finalize_authentik_outpost()` |
| 6 | Medium | `k8s-apps/__main__.py`: add outpost call + CF tunnel config |
| 7 | High | `terraform/tunnel/main.tf`: remove config block + `terraform state rm` |
| 8 | None | Add/update tests |

## Verification

```bash
# 1. Static tests (pre-deploy)
cd kubernetes-pulumi && uv run pytest tests/static/ tests/integration/test_app_dependencies.py -v

# 2. Pulumi preview (catch config errors)
cd kubernetes-pulumi/k8s-apps && pulumi preview

# 3. After deploy: check outpost pod
kubectl get pods -n authentik -l app.kubernetes.io/managed-by=goauthentik.io

# 4. After deploy: check tunnel routes
curl -v https://vault.smadja.dev  # Should redirect to auth.smadja.dev

# 5. Integration tests
cd kubernetes-pulumi && uv run pytest tests/integration/test_connectivity.py -v
```

## Potential Issues

- **Terraform state conflict**: The `cloudflare_zero_trust_tunnel_cloudflared_config` resource must be removed from TF state before Pulumi creates its own. Run `terraform state rm` first.
- **Outpost service name**: Authentik auto-generates the service name as `ak-outpost-<outpost-name>`. If the name changes, the CF routing will break. The name `authentik-embedded-outpost` is hardcoded in both `registry.py` and `k8s-apps/__main__.py`.
- **Pulumi `pulumi_authentik` SDK**: Verify that the installed version supports `ProviderProxy`, `ProviderOauth2`, `Application`, `ServiceConnectionKubernetes`, `Outpost`. Check `pyproject.toml` for version constraints.
- **Doppler secrets**: `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_TUNNEL_ID`, `CLOUDFLARE_API_TOKEN` must exist in Doppler `infrastructure/prd`.
