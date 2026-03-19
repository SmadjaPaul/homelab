#!/usr/bin/env python3
"""
Auto-generates SERVICE-CATALOG.md from apps.yaml.
Run after modifying apps.yaml to keep context in sync.

Usage:
    uv run python scripts/update-context.py
"""

import yaml
from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).parent.parent
APPS_YAML = ROOT / "kubernetes-pulumi" / "apps.yaml"
SERVICE_CATALOG = ROOT / "docs" / "SERVICE-CATALOG.md"


def load_apps():
    with open(APPS_YAML) as f:
        return yaml.safe_load(f)


def generate_service_catalog(data: dict) -> str:
    apps = data.get("apps", [])
    buckets = data.get("buckets", [])
    updated = datetime.now().strftime("%Y-%m-%d")

    lines = [
        "# Service Catalog (auto-generated from apps.yaml)",
        "",
        f"> Last updated: {updated} — Edit `apps.yaml`, then run `scripts/update-context.py`",
        "",
    ]

    # Group by mode
    protected = [a for a in apps if a.get("mode") == "protected"]
    public = [a for a in apps if a.get("mode") == "public"]
    internal = [a for a in apps if a.get("mode") not in ("protected", "public")]

    def app_table(app_list, title):
        if not app_list:
            return []
        rows = [
            f"## {title}",
            "",
            "| Name | Namespace | URL | Helm Chart | Mode |",
            "|------|-----------|-----|------------|------|",
        ]
        for app in app_list:
            name = app.get("name", "")
            ns = app.get("namespace", "")
            hostname = app.get("hostname", "")
            url = f"https://{hostname}" if hostname else "-"
            chart = app.get("helm", {}).get("chart", "-") if app.get("helm") else "-"
            mode = app.get("mode", "-")
            rows.append(f"| **{name}** | `{ns}` | {url} | `{chart}` | {mode} |")
        rows.append("")
        return rows

    lines += app_table(protected, "Protected Apps (Authentik SSO)")
    lines += app_table(public, "Public Apps")
    lines += app_table(internal, "Internal / Infrastructure Apps")

    if buckets:
        lines += [
            "## S3 Buckets",
            "",
            "| Name | Provider | Purpose | Tier |",
            "|------|----------|---------|------|",
        ]
        for b in buckets:
            lines.append(
                f"| `{b['name']}` | {b.get('provider', '-')} | {b.get('purpose', '-')} | {b.get('tier', '-')} |"
            )
        lines.append("")

    return "\n".join(lines)


def main():
    print(f"Reading {APPS_YAML}...")
    data = load_apps()

    catalog = generate_service_catalog(data)

    print(f"Writing {SERVICE_CATALOG}...")
    SERVICE_CATALOG.write_text(catalog)

    app_count = len(data.get("apps", []))
    bucket_count = len(data.get("buckets", []))
    print(f"Done. {app_count} apps, {bucket_count} buckets.")


if __name__ == "__main__":
    main()
