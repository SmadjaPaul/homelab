import os
from shared.apps.loader import AppLoader
from shared.utils.schemas import ExposureMode


def test_protected_apps_depend_on_cloudflared():
    """
    Architectural Rule: Any application with mode=PROTECTED or mode=PUBLIC
    exposed via Cloudflare must have 'cloudflared' in its dependencies
    to ensure the tunnel is ready before the app tries to register.
    """
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    apps_yaml_path = os.path.join(project_root, "apps.yaml")

    loader = AppLoader(apps_yaml_path)
    # We check for both 'oci' and 'local' clusters as the rule applies to both
    for cluster in ["oci", "local"]:
        apps = loader.load_for_cluster(cluster)
        for app in apps:
            # Skip cloudflared itself and infrastructure apps that don't use the tunnel
            if app.name in [
                "cloudflared",
                "kube-system",
                "external-secrets",
                "cert-manager",
            ]:
                continue

            if app.mode in [ExposureMode.PROTECTED, ExposureMode.PUBLIC]:
                assert "cloudflared" in app.dependencies, (
                    f"App '{app.name}' in cluster '{cluster}' is {app.mode.value} but missing 'cloudflared' dependency"
                )


def test_database_apps_depend_on_cnpg():
    """
    Architectural Rule: Apps using a local database must depend on 'cnpg-system'.
    """
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    apps_yaml_path = os.path.join(project_root, "apps.yaml")

    loader = AppLoader(apps_yaml_path)
    for cluster in ["oci", "local"]:
        apps = loader.load_for_cluster(cluster)
        for app in apps:
            if app.database and app.database.local:
                assert "cnpg-system" in app.dependencies, (
                    f"App '{app.name}' in cluster '{cluster}' uses local DB but missing 'cnpg-system' dependency"
                )


def test_protected_apps_depend_on_authentik():
    """Apps with mode=protected must have 'authentik' in dependencies."""
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    loader = AppLoader(os.path.join(project_root, "apps.yaml"))
    for cluster in ["oci", "local"]:
        apps = loader.load_for_cluster(cluster)
        for app in apps:
            if app.name in ["authentik", "kube-system", "external-secrets"]:
                continue
            if app.mode.value == "protected":
                assert "authentik" in app.dependencies, (
                    f"App '{app.name}' is protected but missing 'authentik' dependency"
                )
