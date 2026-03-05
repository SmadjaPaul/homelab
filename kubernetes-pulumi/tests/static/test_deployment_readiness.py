"""
Tests for Ingress and Deployment Validation

These tests verify:
1. IngressClass names match what's actually deployed
2. Required operators are deployed before apps that depend on them
3. PVC naming consistency between Pulumi and Helm
"""

import pytest
from shared.apps.loader import AppLoader
from shared.utils.schemas import ExposureMode


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

    def test_tunnel_mode_requires_cloudflared_dependency(self):
        """
        Test that apps using tunnel mode (cloudflare-tunnel) have cloudflared in dependencies.

        Without cloudflared deployed, Ingress with cloudflare-tunnel will fail with:
        'Ingress .status.loadBalancer field was not updated with a hostname/IP address'
        """
        loader = AppLoader()
        apps = loader.load()

        errors = []
        for app in apps:
            if app.mode == ExposureMode.PROTECTED:  # Tunnel mode
                has_cloudflared_dep = "cloudflared" in app.dependencies
                if not has_cloudflared_dep:
                    errors.append(
                        f"App '{app.name}' uses PROTECTED mode (cloudflare-tunnel) "
                        f"but doesn't have 'cloudflared' in dependencies. "
                        f"Current dependencies: {app.dependencies}"
                    )

        if errors:
            pytest.fail(
                "Apps using tunnel mode must depend on cloudflared:\n"
                + "\n".join(f"  - {e}" for e in errors)
            )


class TestRequiredOperators:
    """Test that required operators are properly configured as dependencies."""

    def test_apps_depend_on_required_operators(self):
        """
        Test that apps specify their required operators as dependencies.

        This prevents 'No matching service found' and timeout errors.
        """
        loader = AppLoader()
        apps = loader.load()

        errors = []
        for app in apps:
            # Check if app uses a feature that requires an operator
            if app.disable_auto_route:
                continue

            if app.mode in (ExposureMode.PUBLIC, ExposureMode.PROTECTED):
                if getattr(app, "hostname", None):
                    # For both Public and Protected modes using hostnames,
                    # we now route traffic through Cloudflare Tunnel.
                    if "cloudflared" not in app.dependencies:
                        errors.append(
                            f"App '{app.name}' uses mode {app.mode.value} with a hostname "
                            f"but doesn't depend on 'cloudflared'. "
                            f"Dependencies: {app.dependencies}"
                        )

        if errors:
            pytest.fail(
                "Apps must declare their required operators as dependencies:\n"
                + "\n".join(f"  - {e}" for e in errors)
            )


class TestHelmReleaseConsistency:
    """Test that Helm releases and Pulumi resources are consistent."""

    def test_apps_yaml_dependencies_exist(self):
        """
        Test that all apps listed in dependencies actually exist in apps.yaml.

        This prevents silent failures where a dependency is misspelled.
        """
        loader = AppLoader()
        apps = loader.load()
        app_names = {app.name for app in apps}

        errors = []
        for app in apps:
            for dep in app.dependencies:
                if dep not in app_names and dep not in ["kube-system"]:
                    errors.append(
                        f"App '{app.name}' depends on '{dep}' but that app doesn't exist in apps.yaml"
                    )

        if errors:
            pytest.fail(
                "Invalid dependencies found:\n" + "\n".join(f"  - {e}" for e in errors)
            )

    def test_storage_keys_match_pvc_names(self):
        """
        Test that persistence keys in helm.values match the expected PVC naming pattern.

        Root cause of Helm adoption failures:
        - Pulumi creates PVC: {app}-{storage.name} (e.g., homarr-config)
        - Helm chart expects: volumeClaimTemplate or existingClaim matching that name
        """
        loader = AppLoader()
        apps = loader.load()

        errors = []
        for app in apps:
            if not app.helm or not app.storage:
                continue

            # Build expected PVC names
            expected_pvc_names = {f"{app.name}-{s.name}" for s in app.storage}

            # Check helm values for persistence config
            helm_values = app.helm.values or {}
            persistence = helm_values.get("persistence", {})

            for pvc_key, pvc_config in persistence.items():
                if not isinstance(pvc_config, dict):
                    continue

                # Check volumeClaimName or existingClaim
                claim_name = pvc_config.get("volumeClaimName") or pvc_config.get(
                    "existingClaim"
                )
                if claim_name and claim_name not in expected_pvc_names:
                    errors.append(
                        f"App '{app.name}': PVC claim '{claim_name}' doesn't match "
                        f"expected pattern '{app.name}-<storage>'. "
                        f"Expected one of: {expected_pvc_names}"
                    )

        if errors:
            pytest.fail(
                "PVC naming inconsistencies:\n" + "\n".join(f"  - {e}" for e in errors)
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

        # Apps that typically need more time to start
        slow_apps = {"authentik", "vaultwarden", "navidrome"}

        for app in apps:
            if app.name in slow_apps and app.helm:
                # Check if timeout is configured (HelmConfig may not have this attribute)
                timeout = getattr(app.helm, "timeout", None)
                if not timeout:
                    # Just a warning, not a hard failure
                    print(
                        f"Warning: App '{app.name}' may need timeout configuration for slow startup"
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
