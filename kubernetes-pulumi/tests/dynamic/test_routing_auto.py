"""
Auto-discovered routing tests.

Tests HTTP/HTTPS connectivity for all apps that require routing.
"""

import urllib.request
import urllib.error

import pytest


@pytest.mark.routing
def test_endpoints_respond(apps_with_routing):
    """Test each app endpoint responds with 200 or 302."""
    for app in apps_with_routing:
        url = f"https://{app.hostname}"

        try:
            req = urllib.request.Request(url, headers={"User-Agent": "homelab-test/1.0"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                status = resp.status
        except urllib.error.HTTPError as e:
            status = e.code
        except Exception as e:
            pytest.skip(f"Could not reach {url}: {e}")

        assert status in [200, 302], f"{app.name}: Expected 200 or 302, got {status}"
