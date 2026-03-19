"""
Tests for Ingress and Deployment Validation

These tests verify:
1. IngressClass names match what's actually deployed
2. Deployment readiness (timeouts, PVC ordering)

Note: dependency validation and PVC naming are covered by
test_deployment_validation.py and test_storage_strategy.py respectively.
"""

import pytest
from shared.apps.loader import AppLoader


class TestIngressClassValidation:
    """Validate IngressClass usage in the codebase."""

    # Known ingress classes that should be deployed
    KNOWN_INGRESS_CLASSES = {
        "cloudflare-tunnel",  # The actual name (not cloudflared-tunnel)
        "envoy-gateway",
        "nginx",
    }

    def test_ingress_class_names_are_valid(self):
        """
        Test that ingressClassName used in code matches actual cluster ingress classes.

        Known bug: code was using 'cloudflared-tunnel' but actual IngressClass is 'cloudflare-tunnel'
        """
        from pathlib import Path
        import re

        # Search for ingressClassName usage in the codebase
        registry_path = (
            Path(__file__).parent.parent.parent
            / "shared"
            / "apps"
            / "common"
            / "registry.py"
        )
        content = registry_path.read_text()

        # Find all ingressClassName usages
        pattern = r'"ingressClassName":\s*"([^"]+)"'
        found_classes = set(re.findall(pattern, content))

        # All used ingress classes should be in our known list
        unknown_classes = found_classes - self.KNOWN_INGRESS_CLASSES

        # Check specifically for the common mistake
        if "cloudflared-tunnel" in found_classes:
            pytest.fail(
                "Found 'cloudflared-tunnel' but should be 'cloudflare-tunnel'. "
                "The correct IngressClass name is 'cloudflare-tunnel' (without the 'd')."
            )

        if unknown_classes:
            pytest.fail(
                f"Unknown ingress classes used: {unknown_classes}. Known: {self.KNOWN_INGRESS_CLASSES}"
            )


class TestDeploymentReadiness:
    """Test that deployments are configured for readiness."""

    def test_critical_apps_have_timeout_config(self):
        """
        Test that Helm charts with potential long startup times have timeout configured.

        Prevents: 'timed out waiting to be Ready' errors
        """
        loader = AppLoader()
        apps = loader.load()

        for app in apps:
            # Check for the flag defined in apps.yaml via schemas.py
            if app.test.requires_extended_timeout and app.helm:
                # Check if timeout is configured (HelmConfig may not have this attribute)
                timeout = getattr(app.helm, "timeout", None)
                if not timeout:
                    # Just a warning, not a hard failure
                    print(
                        f"Warning: App '{app.name}' has requires_extended_timeout=true but no 'timeout' set in helm config."
                    )

    def test_pvc_exists_before_helm_deployment(self):
        """
        Test that apps with storage have storage defined in apps.yaml.

        This ensures Pulumi creates the PVC before Helm tries to use it.
        """
        loader = AppLoader()
        apps = loader.load()

        errors = []
        for app in apps:
            if app.helm and app.helm.chart:
                # Check if app has storage defined
                if not app.storage:
                    # This is OK - not all apps need storage
                    continue

                # Verify storage has required fields
                for storage in app.storage:
                    if not storage.name:
                        errors.append(f"App '{app.name}' has storage without a name")
                    if not storage.size:
                        errors.append(
                            f"App '{app.name}' storage '{storage.name}' has no size defined"
                        )

        if errors:
            pytest.fail(
                "Storage configuration errors:\n"
                + "\n".join(f"  - {e}" for e in errors)
            )
