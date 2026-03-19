"""
Static tests — Networking conventions.

Validates that apps configured in apps.yaml follow routing conventions:
- PUBLIC/PROTECTED apps use external hostnames
- All hostnames follow the *.smadja.dev pattern
- No two apps share the same hostname
"""

import re
import pytest

from shared.utils.schemas import ExposureMode
from shared.apps.loader import load_apps

# Hostname pattern for *.smadja.dev
EXTERNAL_HOSTNAME_PATTERN = re.compile(
    r"^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.smadja\.dev$"
)
INTERNAL_HOSTNAME_PATTERN = re.compile(r"^[a-z0-9-]+\.[a-z0-9-]+\.svc\.cluster\.local$")


@pytest.fixture(scope="module")
def apps():
    """Load apps for testing."""
    return load_apps("oci")


class TestHostnameConventions:
    """All hostnames must follow the project naming convention."""

    def test_public_apps_have_external_hostname(self, apps):
        """Public/Protected apps must use the *.smadja.dev domain."""
        for app in apps:
            if (
                app.network.mode in (ExposureMode.PUBLIC, ExposureMode.PROTECTED)
                and app.network.hostname
            ):
                assert EXTERNAL_HOSTNAME_PATTERN.match(app.network.hostname), (
                    f"App '{app.name}' has mode={app.network.mode.value} but hostname "
                    f"'{app.network.hostname}' doesn't match *.smadja.dev."
                )

    def test_no_duplicate_hostnames(self, apps):
        """No two apps should share the same external hostname."""
        hostnames = {}
        for app in apps:
            if not app.network.hostname:
                continue
            if app.network.hostname in hostnames:
                pytest.fail(
                    f"Duplicate hostname '{app.network.hostname}' used by both "
                    f"'{hostnames[app.network.hostname]}' and '{app.name}'. "
                )
            hostnames[app.network.hostname] = app.name

    def test_hostnames_are_lowercase(self, apps):
        """Hostnames must be lowercase (RFC 1035)."""
        for app in apps:
            if app.network.hostname:
                assert app.network.hostname == app.network.hostname.lower(), (
                    f"App '{app.name}' has hostname '{app.network.hostname}' which is not all-lowercase."
                )

    def test_hostnames_dont_have_trailing_slash_or_protocol(self, apps):
        """Hostnames should not include a trailing slash, path, or protocol."""
        for app in apps:
            if app.network.hostname:
                assert "/" not in app.network.hostname, (
                    f"App '{app.name}' hostname '{app.network.hostname}' contains a '/'."
                )
                assert not app.network.hostname.startswith("http"), (
                    f"App '{app.name}' hostname '{app.network.hostname}' starts with 'http'."
                )


class TestExposureModes:
    """Validate app exposure mode assignments."""

    def test_apps_have_valid_port(self, apps):
        """All apps exposing a service must have a port > 0."""
        for app in apps:
            # If an app has a mode and it exposes something, it has a port
            if app.network.port is not None:
                assert app.network.port > 0, (
                    f"App '{app.name}' has invalid port {app.network.port}."
                )

    def test_internal_apps_dont_expose_to_internet(self, apps):
        """INTERNAL apps should NOT use the external domain."""
        for app in apps:
            if app.network.mode == ExposureMode.INTERNAL and app.network.hostname:
                is_external = EXTERNAL_HOSTNAME_PATTERN.match(app.network.hostname)
                if is_external:
                    pytest.fail(
                        f"Internal app '{app.name}' has an external hostname "
                        f"'{app.network.hostname}'. Internal apps should not use the external domain convention."
                    )

    def test_sensitive_apps_not_in_default(self, apps):
        """Sensitive services should not be in 'default' namespace."""
        sensitive_names = {
            "authentik",
            "grafana",
            "prometheus",
            "vaultwarden",
            "redis",
            "postgresql",
            "cnpg-system",
        }
        for app in apps:
            if app.name in sensitive_names:
                assert app.namespace != "default", (
                    f"Sensitive service '{app.name}' is in namespace 'default'. "
                    "Move it to a dedicated namespace."
                )
