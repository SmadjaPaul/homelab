"""Verify that CF tunnel routing follows the correct pattern for each app mode."""

import os
import pytest
import sys

# Add project root to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from shared.apps.loader import AppLoader
from shared.utils.schemas import ExposureMode

OUTPOST_SVC = "ak-outpost-authentik-embedded-outpost.authentik.svc.cluster.local:9000"


def get_apps():
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    loader = AppLoader(os.path.join(project_root, "apps.yaml"))
    return loader.load_for_cluster("oci")


def build_svc_url(app):
    """Replicate the routing logic from k8s-apps/__main__.py."""
    if app.mode == ExposureMode.PROTECTED:
        return f"http://{OUTPOST_SVC}"
    svc_name = "authentik-server" if app.name == "authentik" else app.name
    return f"http://{svc_name}.{app.namespace}.svc.cluster.local:{app.port}"


@pytest.mark.parametrize(
    "app",
    [a for a in get_apps() if a.hostname and a.mode.value in ("public", "protected")],
)
def test_routing_logic_for_exposed_apps(app):
    """Verify that routing follows the correct security pattern."""
    svc_url = build_svc_url(app)

    if app.mode == ExposureMode.PROTECTED:
        assert OUTPOST_SVC in svc_url, (
            f"Protected app {app.name} MUST route through the Authentik Outpost for safety."
        )
    else:
        assert OUTPOST_SVC not in svc_url, (
            f"Public app {app.name} should NOT route through the Authentik Outpost (bypass for performance)."
        )
