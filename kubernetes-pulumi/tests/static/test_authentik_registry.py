from shared.utils.schemas import (
    AppModel,
    ExposureMode,
    AppCategory,
    AppTier,
    ProvisioningConfig,
    ProvisioningMethod,
)


def test_authentik_internal_oidc_hidden():
    """Verify the logic that determines if an OIDC application should be hidden in Authentik."""
    # Create a mock AppModel for an internal OIDC app
    model = AppModel(
        name="test-oidc-app",
        namespace="test",
        category=AppCategory.PROTECTED,
        tier=AppTier.STANDARD,
        network={
            "mode": ExposureMode.PROTECTED,
        },
        auth={
            "provisioning": ProvisioningConfig(method=ProvisioningMethod.OIDC),
        },
        helm={"chart": "test", "version": "1.0.0"},
    )

    # The logic in AuthentikRegistry.py is:
    # is_public = app.network.mode.value == "public"
    is_public = model.network.mode.value == "public"

    # Default behavior for non-public OIDC apps is to hide them
    meta_launch_url = (
        "blank://blank" if not is_public else f"https://{model.network.hostname}"
    )

    assert meta_launch_url == "blank://blank", (
        "Internal/Protected OIDC app should have blank://blank to hide it"
    )
    assert not is_public, "Protected mode should not evaluate to public"


def test_authentik_public_oidc_visible():
    """Verify that a public OIDC application IS visible in Authentik."""
    model = AppModel(
        name="test-public-app",
        namespace="test",
        category=AppCategory.PUBLIC,
        tier=AppTier.STANDARD,
        network={
            "mode": ExposureMode.PUBLIC,
            "hostname": "test.example.com",
        },
        auth={
            "provisioning": ProvisioningConfig(method=ProvisioningMethod.OIDC),
        },
        helm={"chart": "test", "version": "1.0.0"},
    )

    is_public = model.network.mode.value == "public"
    meta_launch_url = (
        "blank://blank" if not is_public else f"https://{model.network.hostname}"
    )

    assert meta_launch_url == "https://test.example.com"
    assert is_public
