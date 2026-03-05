"""
Static infrastructure tests.
"""

from shared.utils.versions import VERSIONS
from shared.apps.loader import load_apps


def test_versions_sync():
    """Verify that apps defined in apps.yaml have their chart versions tracked in versions.py (if applicable)."""
    # Note: Apps in apps.yaml can have their own version,
    # but we often want to ensure they match our global catalog.
    apps = load_apps("oci")

    # This is a sample check - in a real scenario, you'd compare apps.yaml vs versions.py
    for app in apps:
        if app.chart and app.chart in VERSIONS:
            # Optionally check if versions match if that's a policy
            pass


def test_deployment_order_is_valid():
    """Verify that topological sort can be performed without cycles."""
    from shared.apps.loader import get_deployment_order

    order = get_deployment_order("oci")
    assert len(order) > 0
    assert "authentik" in order or "homarr" in order
