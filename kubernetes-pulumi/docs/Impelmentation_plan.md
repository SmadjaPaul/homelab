# Implementation Plan — Authentik Proxy Auth + CF Tunnel Migration

## Target Architecture

```
Internet → Cloudflare Tunnel → Authentik Outpost (:9000) → Backend App
                                    ↕
                              Authentik Server
                              (auth flows, sessions)
```

---

## Changes Required

### 1. `apps.yaml` — Enable `auth: true` on protected apps
- Add `auth: true` to `navidrome` and `vaultwarden`.

### 2. `schemas.py` — Auto-derive `auth`
- Add `@model_validator` to `AppModel` to set `auth = True` for `mode: protected`.

### 3. `registry.py` — Clean up and Outpost Setup
- Remove ~113 lines of dead exposure code.
- Fix `_setup_auth_for_app` using `authentik.ProviderProxy` (mode="proxy").
- **[USER FEEDBACK]** Add `invalidation_flow="default-provider-invalidation-flow"`.
- Implement `finalize_authentik_outpost()` using `authentik.Outpost` and `authentik.ServiceConnectionKubernetes`.
- Use the name `authentik-embedded-outpost` (Service: `ak-outpost-authentik-embedded-outpost.authentik.svc.cluster.local:9000`).

### 4. `k8s-apps/__main__.py` — Deployment Orchestration
- Call `registry.finalize_authentik_outpost()` in Phase 3.
- Implement Phase 4: Dynamic Cloudflare Tunnel config using `pulumi_cloudflare.ZeroTrustTunnelCloudflaredConfig`.

### 5. Terraform — State Management
- Remove `cloudflare_zero_trust_tunnel_cloudflared_config` from `main.tf`.
- **[CRITICAL]** Run `terraform state rm 'module.tunnel[0].cloudflare_zero_trust_tunnel_cloudflared_config.homelab[0]'` before Pulumi apply.

---

## New Tests to Add

### Integration: Outpost Status
Check that the pod is actually running.
```python
def test_authentik_outpost_running():
    import kubernetes
    client = kubernetes.client.CoreV1Api()
    pods = client.list_namespaced_pod("authentik")
    outpost_pods = [p for p in pods.items if "outpost" in p.metadata.name]
    assert len(outpost_pods) > 0, "No authentik outpost pod found"
```

### Static: Routing Logic
Verify `mode: public` doesn't accidentally route through the outpost.
```python
def test_public_apps_not_through_outpost():
    for app in apps:
        if app.mode == ExposureMode.PUBLIC:
            svc_url = build_svc_url(app)
            assert "outpost" not in svc_url
```

---

## Verification Steps
1. `uv run pytest tests/static/`
2. `terraform state rm ...`
3. `pulumi up`
4. `uv run pytest tests/integration/test_connectivity.py`
