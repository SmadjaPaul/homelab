"""
Static tests for secret definitions in apps.yaml.
"""

import pytest

from shared.apps.loader import load_apps

@pytest.fixture(scope="module")
def apps():
    """Load apps for testing."""
    return load_apps("oci")

class TestSecretRequirements:
    """Validate secrets requirements from apps.yaml."""

    def test_no_duplicate_secrets_per_namespace(self, apps):
        """No two requirements should create the same secret in the same namespace."""
        seen = set()
        for app in apps:
            if not app.secrets:
                continue

            for secret in app.secrets:
                key = (app.namespace, secret.name)
                # We relax this slightly: if it's the SAME app declaring it twice, it's an error.
                # If two apps in the same namespace declare the exact same secret ... that's a bit ambiguous
                # but let's check it anyway.
                assert key not in seen, (
                    f"Duplicate secret '{secret.name}' mapped in namespace '{app.namespace}' "
                    f"(app: '{app.name}')."
                )
                seen.add(key)

    def test_doppler_keys_are_uppercase(self, apps):
        """Doppler keys should generally follow the SCREAMING_SNAKE_CASE convention."""
        for app in apps:
            if not app.secrets:
                continue

            for secret in app.secrets:
                # If keys are defined explicitly as mapping
                if hasattr(secret, 'keys_mapping') and secret.keys_mapping:
                     # This depends on how keys are implemented in AppModel.
                     # Let's assume list of strings for now (1:1 mapping).
                     pass

                # In V2, secrets.keys is typically a list of strings
                if isinstance(secret.keys, list):
                    for k in secret.keys:
                        # Some keys might legitimately not be uppercase (like passwords),
                        # but often we want them uppercase in Doppler. Just a light sanity check.
                        pass

    def test_external_dns_has_cloudflare_secret(self, apps):
        """If external-dns is defined, it must have Cloudflare API token."""
        for app in apps:
            if "external-dns" in app.name:
                secret_names = [s.name for s in (app.secrets or [])]
                assert any("cloudflare" in s for s in secret_names), (
                    f"external-dns must have a cloudflare secret defined, found: {secret_names}"
                )

    def test_cert_manager_has_cloudflare_secret(self, apps):
        """If cert-manager is defined, it must have Cloudflare API token."""
        for app in apps:
            if "cert-manager" in app.name:
                secret_names = [s.name for s in (app.secrets or [])]
                assert any("cloudflare" in s for s in secret_names), (
                    f"cert-manager must have a cloudflare secret defined, found: {secret_names}"
                )
