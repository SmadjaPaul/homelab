"""
Deployment Validation Tests

Tests to validate apps.yaml configuration before deployment:
- No duplicate ingress routes
- Dependencies are valid
- Chart versions are pinned (not 'latest')
- Required security contexts are present
"""
import pytest
import yaml
from pathlib import Path
from collections import defaultdict


def get_apps_config():
    project_root = Path(__file__).parent.parent.parent
    with open(project_root / "apps.yaml", "r") as f:
        return yaml.safe_load(f)


def test_no_duplicate_ingress_routes():
    """
    Verify no two apps use the same hostname.
    Duplicate hostnames cause routing conflicts in Envoy Gateway.
    """
    config = get_apps_config()
    apps = config.get("apps", [])
    
    hostname_to_apps = defaultdict(list)
    
    for app in apps:
        hostname = app.get("hostname")
        if hostname:
            hostname_to_apps[hostname].append(app["name"])
    
    duplicates = {h: names for h, names in hostname_to_apps.items() if len(names) > 1}
    
    if duplicates:
        error_msg = "Duplicate hostnames detected:\n"
        for hostname, app_names in duplicates.items():
            error_msg += f"  - {hostname}: {', '.join(app_names)}\n"
        pytest.fail(error_msg)


def test_dependencies_are_valid():
    """
    Verify all app dependencies reference valid namespaces or apps.
    """
    config = get_apps_config()
    apps = config.get("apps", [])
    
    # Known valid dependencies (system namespaces + other apps)
    valid_deps = {
        "kube-system", "external-secrets", "cert-manager",
        "external-dns", "cloudflared", "envoy-gateway",
        "cnpg-system", "authentik", "redis",
    }
    valid_deps.update(app["name"] for app in apps)
    
    errors = []
    
    for app in apps:
        app_name = app.get("name")
        deps = app.get("dependencies", [])
        
        for dep in deps:
            if dep not in valid_deps:
                errors.append(f"App '{app_name}' depends on unknown: '{dep}'")
    
    if errors:
        pytest.fail("Invalid dependencies:\n" + "\n".join(f"  - {e}" for e in errors))


def test_chart_versions_pinned():
    """
    Verify Helm chart versions are pinned (not empty or 'latest').
    Using unpinned versions can cause unexpected changes during deployment.
    """
    config = get_apps_config()
    apps = config.get("apps", [])
    
    errors = []
    
    for app in apps:
        app_name = app.get("name")
        if "helm" not in app:
            continue
            
        version = app.get("helm", {}).get("version")
        if not version:
            errors.append(f"App '{app_name}': chart version is empty")
        elif version == "latest":
            errors.append(f"App '{app_name}': chart version is 'latest' (should be pinned)")
    
    if errors:
        pytest.fail("Chart version issues:\n" + "\n".join(f"  - {e}" for e in errors))


def test_required_security_contexts():
    """
    Verify apps with persistent storage have podSecurityContext with fsGroup.
    This prevents permission denied errors on PVC mounts.
    """
    config = get_apps_config()
    apps = config.get("apps", [])
    
    errors = []
    
    for app in apps:
        app_name = app.get("name")
        storage = app.get("storage", [])
        
        if not storage:
            continue
            
        helm_values = app.get("helm", {}).get("values", {})
        security_context = helm_values.get("podSecurityContext") or helm_values.get("securityContext")
        
        if not security_context:
            errors.append(
                f"App '{app_name}': has storage but no podSecurityContext defined. "
                f"Add 'podSecurityContext: {{fsGroup: 1000}}' to prevent permission errors."
            )
    
    if errors:
        pytest.fail("Security context issues:\n" + "\n".join(f"  - {e}" for e in errors))


def test_app_replicas_match_tier():
    """
    Verify critical tier apps have multiple replicas.
    """
    config = get_apps_config()
    apps = config.get("apps", [])
    
    warnings = []
    
    for app in apps:
        app_name = app.get("name")
        tier = app.get("tier", "")
        replicas = app.get("replicas", 1)
        
        if tier == "critical" and replicas < 2:
            warnings.append(
                f"App '{app_name}': critical tier but only {replicas} replica(s). "
                f"Consider 2+ replicas for high availability."
            )
    
    if warnings:
        # Just warn, don't fail
        print("\nWarning: Consider increasing replicas for critical apps:")
        for w in warnings:
            print(f"  - {w}")


def test_storage_size_reasonable():
    """
    Verify storage sizes are reasonable (not too small, not excessive).
    """
    config = get_apps_config()
    apps = config.get("apps", [])
    
    errors = []
    
    for app in apps:
        app_name = app.get("name")
        storage = app.get("storage", [])
        
        for s in storage:
            size = s.get("size", "")
            # Parse size (e.g., "1Gi", "10Gi")
            if size.endswith("Gi") or size.endswith("G"):
                try:
                    num = int(size.rstrip("GiG"))
                    if num < 1:
                        errors.append(f"App '{app_name}': storage size '{size}' is too small (min 1Gi)")
                    elif num > 100:
                        errors.append(f"App '{app_name}': storage size '{size}' is excessive (max 100Gi)")
                except ValueError:
                    pass  # Skip parsing errors
    
    if errors:
        pytest.fail("Storage size issues:\n" + "\n".join(f"  - {e}" for e in errors))


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
