#!/usr/bin/env python3
"""
Deployment Summary — dry-run sanity check before `pulumi up`.

Loads apps.yaml, simulates conventions, and prints a human-readable
summary of what would be deployed: tunnel rules, Authentik providers,
SSO presets, storage volumes.

Usage:
    cd kubernetes-pulumi
    uv run python scripts/deployment_check.py [--cluster oci]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from shared.apps.loader import AppLoader
from shared.utils.preflight import validate_all, UI_ONLY_OIDC


def main():
    parser = argparse.ArgumentParser(description="Deployment Summary")
    parser.add_argument("--cluster", default="oci", help="Target cluster")
    args = parser.parse_args()

    loader = AppLoader()
    raw_config = loader.get_full_config()
    domain = raw_config.get("domain", "smadja.dev")
    apps = loader.load_for_cluster(args.cluster)

    print(f"\n{'=' * 60}")
    print(f"  Deployment Summary (cluster: {args.cluster})")
    print(f"{'=' * 60}")
    print(f"\n{len(apps)} apps loaded\n")

    # ── Preflight Validation ──────────────────────────────────
    print("─── Preflight Validation ───")
    errors = validate_all(apps, domain)
    if errors:
        for e in errors:
            print(f"  ❌ {e}")
        print()
    else:
        print("  ✅ All validations passed\n")

    # ── Tunnel Rules ──────────────────────────────────────────
    print("─── Tunnel Rules ───")
    tunnel_count = 0
    for app in sorted(apps, key=lambda a: a.name):
        hostname = app.network.hostname
        if hostname:
            mode = app.network.mode.value if app.network.mode else "?"
            if mode == "protected":
                target = "→ authentik-outpost"
            else:
                svc = app.service_name or app.name
                target = f"→ {svc}:{app.network.port}"
            print(f"  ✅ {hostname} {target} ({mode})")
            tunnel_count += 1
        else:
            mode = app.network.mode.value if app.network.mode else "internal"
            print(f"  ⬚  {app.name} — no hostname ({mode}, skipped)")
    print(f"\n  Total: {tunnel_count} tunnel rules\n")

    # ── Authentik Providers ───────────────────────────────────
    print("─── Authentik Providers ───")
    proxy_apps = []
    oidc_apps = []
    for app in apps:
        if app.auth.sso == "authentik-header":
            proxy_apps.append(app.name)
        elif app.auth.sso == "authentik-oidc":
            oidc_apps.append(app.name)

    if proxy_apps:
        print(f"  Proxy: {len(proxy_apps)} ({', '.join(sorted(proxy_apps))})")
    if oidc_apps:
        print(f"  OIDC:  {len(oidc_apps)} ({', '.join(sorted(oidc_apps))})")
    print()

    # ── SSO Presets ───────────────────────────────────────────
    print("─── SSO Preset Status ───")
    for app in sorted(apps, key=lambda a: a.name):
        if not app.auth.sso:
            continue

        if app.name in UI_ONLY_OIDC:
            print(f"  ⚠️  {app.name} — OIDC (UI-only config, no env vars injected)")
        elif app.auth.sso == "authentik-oidc":
            injected = [
                k for k in app.extra_env if "OIDC" in k or "SSO" in k or "OAUTH" in k
            ]
            if injected:
                print(f"  ✅ {app.name} — OIDC: {', '.join(injected[:4])}")
            else:
                print(f"  ⚠️  {app.name} — OIDC but no OIDC env vars found")
        elif app.auth.sso == "authentik-header":
            injected = [
                k
                for k in app.extra_env
                if "HEADER" in k or "EXTAUTH" in k or "REMOTE" in k
            ]
            if injected:
                print(f"  ✅ {app.name} — Header: {', '.join(injected[:3])}")
            else:
                print(f"  ✅ {app.name} — Header (default env vars)")
    print()

    # ── Storage ───────────────────────────────────────────────
    print("─── Storage ───")
    pvc_count = 0
    smb_issues = 0
    for app in sorted(apps, key=lambda a: a.name):
        for s in app.persistence.storage or []:
            sc = getattr(s, "storage_class", "default")
            claim = getattr(s, "existing_claim", None)
            if sc == "hetzner-smb" and not claim:
                print(f"  ❌ {app.name}.{s.name}: hetzner-smb without existing_claim")
                smb_issues += 1
            else:
                pvc_count += 1

    print(f"\n  Total: {pvc_count} PVCs")
    if smb_issues == 0:
        print("  ✅ All hetzner-smb volumes have existing_claim")
    print()

    # ── Final Summary ─────────────────────────────────────────
    if errors or smb_issues:
        print(f"⚠️  {len(errors) + smb_issues} issue(s) found. Fix before deploying.\n")
        sys.exit(1)
    else:
        print("✅ Ready to deploy!\n")


if __name__ == "__main__":
    main()
