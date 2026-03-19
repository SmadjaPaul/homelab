"""
Post-deploy smoke tests for critical services.

Verifies that all tier:critical apps with hostnames respond
with HTTP < 500 after a deployment.

Usage:
    cd kubernetes-pulumi
    uv run pytest tests/smoke/test_endpoints.py -v

NOTE: This requires internet connectivity and a deployed cluster.
      It is NOT run in CI — only after a real `pulumi up`.
"""

import pytest
import yaml
from pathlib import Path

try:
    import requests
except ImportError:
    requests = None


APPS_YAML = Path(__file__).parent.parent.parent / "apps.yaml"


def _load_critical_hostnames() -> list[tuple[str, str]]:
    """Load hostname list for critical apps from apps.yaml."""
    if not APPS_YAML.exists():
        return []

    with open(APPS_YAML) as f:
        config = yaml.safe_load(f) or {}

    domain = config.get("domain", "smadja.dev")
    hostnames = []

    for app in config.get("apps", []):
        tier = app.get("tier", "standard")
        prefix = app.get("hostname_prefix")
        if tier == "critical" and prefix:
            hostnames.append((app["name"], f"{prefix}.{domain}"))

    return hostnames


@pytest.mark.skipif(requests is None, reason="requests not installed")
class TestCriticalEndpoints:
    """Smoke tests for critical application endpoints."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.hostnames = _load_critical_hostnames()
        if not self.hostnames:
            pytest.skip("No critical apps with hostnames found")

    def test_critical_apps_respond(self):
        """All tier:critical apps with hostnames must return HTTP < 500."""
        errors = []
        for name, hostname in self.hostnames:
            try:
                r = requests.get(
                    f"https://{hostname}",
                    timeout=15,
                    allow_redirects=False,
                )
                if r.status_code >= 500:
                    errors.append(f"{name} ({hostname}): HTTP {r.status_code}")
            except requests.RequestException as e:
                errors.append(f"{name} ({hostname}): {e}")

        assert not errors, "Critical apps failing:\n" + "\n".join(errors)

    def test_authentik_reachable(self):
        """Authentik must be reachable — it's the SSO gateway."""
        try:
            r = requests.get(
                "https://auth.smadja.dev",
                timeout=15,
                allow_redirects=False,
            )
            assert r.status_code < 500, f"Authentik returned HTTP {r.status_code}"
        except requests.RequestException as e:
            pytest.fail(f"Authentik unreachable: {e}")
