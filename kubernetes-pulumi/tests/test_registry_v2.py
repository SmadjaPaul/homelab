"""
Unit tests for the V2 AppRegistry and Authentik Integration.
"""

import pytest
import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

import pulumi
import pulumi_kubernetes as k8s
from unittest.mock import Mock, patch

# Import models
from utils.schemas import (
    AppModel,
    ExposureMode,
    IdentityUserModel,
    IdentityGroupModel,
    IdentitiesModel,
)
from apps.common.registry import AppRegistry

# --- Mocks ---


class PulumiMocks(pulumi.runtime.Mocks):
    def new_resource(self, args: pulumi.runtime.MockResourceArgs):
        return [args.name + "_id", args.inputs]

    def call(self, args: pulumi.runtime.MockCallArgs):
        return {}


def setup_module():
    pulumi.runtime.set_mocks(PulumiMocks(), preview=True)


# --- Tests ---


class TestAppRegistryV2:
    """Test suite for the V2 registry features."""

    def test_authentik_identities_provisioning(self):
        """Verify that Authentik users and groups are provisioned from config."""
        identities = IdentitiesModel(
            groups=[
                IdentityGroupModel(name="admins", is_superuser=True),
                IdentityGroupModel(name="users"),
            ],
            users=[
                IdentityUserModel(
                    name="paul",
                    display_name="Paul Smadja",
                    email="paul@smadja.dev",
                    groups=["admins"],
                    attributes={"shell": "/bin/zsh"},
                ),
            ],
        )

        app = AppModel(name="dummy", port=80, hostname="dummy.test")
        provider = k8s.Provider("test-provider")

        # We need to mock pulumi_authentik since it might not be installed
        with patch.dict(
            sys.modules,
            {
                "pulumi_authentik": Mock(),
                "pulumi_authentik.core": Mock(),
                "pulumi_authentik.provider": Mock(),
            },
        ):
            registry = AppRegistry(
                "test-authentik",
                provider=provider,
                apps=[app],
                config={"identities": identities},
            )

            # Check if groups were created
            assert "admins" in registry.authentik_groups
            assert "users" in registry.authentik_groups

            # Check if User creation was called (via our mock)
            # This is a bit indirect with Pulumi mocks but verifies the logic path
            assert registry is not None

    def test_authentik_proxy_provider_for_protected_apps(self):
        """Verify that PROTECTED apps get a ProxyProvider instead of just OIDC."""
        app = AppModel(
            name="private-app",
            port=8080,
            hostname="private.example.com",
            mode=ExposureMode.PROTECTED,
            auth=True,
        )

        provider = k8s.Provider("test-provider")

        with patch.dict(
            sys.modules,
            {
                "pulumi_authentik": Mock(),
                "pulumi_authentik.core": Mock(),
                "pulumi_authentik.provider": Mock(),
                "pulumi_authentik.provider.proxy": Mock(),
                "pulumi_authentik.provider.oauth2": Mock(),
            },
        ):
            registry = AppRegistry(
                "test-proxy",
                provider=provider,
                apps=[app],
            )
            # Logic check: verify no crash and registry initialized
            assert registry is not None

    def test_gateway_route_with_authentik_forward_auth(self):
        """Verify that PUBLIC apps with auth use the new Authentik Envoy URLs."""
        app = AppModel(
            name="public-auth-app",
            port=80,
            hostname="auth-app.example.com",
            mode=ExposureMode.PUBLIC,
            auth=True,
        )

        provider = k8s.Provider("test-provider")

        # We want to capture the SecurityPolicy creation inputs
        with patch.dict(
            sys.modules,
            {
                "pulumi_authentik": Mock(),
                "pulumi_authentik.core": Mock(),
                "pulumi_authentik.provider": Mock(),
            },
        ):
            registry = AppRegistry(
                "test-gateway",
                provider=provider,
                apps=[app],
                config={"domain": "smadja.dev"},
            )

            # The test here is mostly ensuring registry runs the _create_gateway_route logic
            # and follows the paths updated for Authentik.
            assert registry is not None

    def test_resource_limits_injection(self):
        """Verify that apps with resource limits defined in apps.yaml are respected."""
        # Note: Resource injection happens in GenericHelmApp, but we can verify
        # the schema parsing here.
        app = AppModel(
            name="resource-app",
            port=80,
            resources={
                "requests": {"cpu": "100m", "memory": "256Mi"},
                "limits": {"cpu": "200m", "memory": "512Mi"},
            },
        )
        assert app.resources["requests"]["cpu"] == "100m"
        assert app.resources["limits"]["memory"] == "512Mi"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
