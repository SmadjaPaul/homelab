from unittest.mock import patch, MagicMock
from shared.utils.schemas import (
    AppModel,
    ExposureMode,
    AppCategory,
    AppTier,
    ProvisioningConfig,
    ProvisioningMethod,
)
from shared.apps.base import BaseApp, NetworkPolicyBuilder


class MockApp(BaseApp):
    def deploy_components(self, provider, config, opts=None):
        return {}


def test_outpost_selector_matches_real_label():
    """Verify NetworkPolicy pod selector matches actual Authentik outpost pod label."""
    model = AppModel(
        name="protected-app",
        namespace="apps",
        category=AppCategory.PROTECTED,
        tier=AppTier.STANDARD,
        network={
            "mode": ExposureMode.PROTECTED,
            "hostname": "protected.example.com",
        },
        auth={
            "provisioning": ProvisioningConfig(method=ProvisioningMethod.OIDC),
        },
        helm={"chart": "test", "version": "1.0.0"},
    )

    app = MockApp(model)
    builder = NetworkPolicyBuilder(provider=MagicMock())

    with patch("pulumi_kubernetes.networking.v1.NetworkPolicy") as mock_np:
        builder.build(app)

        # Find the call for the tunnel ingress policy
        tunnel_call = next(
            (
                call
                for call in mock_np.call_args_list
                if "allow-tunnel-ingress" in call.args[0]
            ),
            None,
        )

        assert tunnel_call is not None, "Should have created a tunnel-ingress policy"

        # Inspect the 'spec' argument passed to the constructor
        spec = tunnel_call.kwargs["spec"]

        found_outpost_label = False
        for rule in spec.ingress:
            for peer in rule.from_:
                if peer.pod_selector and peer.pod_selector.match_expressions:
                    for req in peer.pod_selector.match_expressions:
                        if (
                            req.key == "app.kubernetes.io/name"
                            and "authentik-outpost-proxy" in req.values
                        ):
                            found_outpost_label = True
                            break

        assert found_outpost_label


def test_public_ingress_from_cloudflare():
    """Verify that PUBLIC apps allow ingress from cloudflared."""
    model = AppModel(
        name="public-app",
        namespace="apps",
        category=AppCategory.PUBLIC,
        tier=AppTier.STANDARD,
        network={
            "mode": ExposureMode.PUBLIC,
            "hostname": "public.example.com",
        },
        helm={"chart": "test", "version": "1.0.0"},
    )

    app = MockApp(model)
    builder = NetworkPolicyBuilder(provider=MagicMock())

    with patch("pulumi_kubernetes.networking.v1.NetworkPolicy") as mock_np:
        builder.build(app)

        tunnel_call = next(
            (
                call
                for call in mock_np.call_args_list
                if "allow-tunnel-ingress" in call.args[0]
            ),
            None,
        )

        assert tunnel_call is not None

        spec = tunnel_call.kwargs["spec"]
        found_cloudflared = False
        for rule in spec.ingress:
            for peer in rule.from_:
                if (
                    peer.namespace_selector
                    and peer.namespace_selector.match_labels
                    and peer.namespace_selector.match_labels.get(
                        "kubernetes.io/metadata.name"
                    )
                    == "cloudflared"
                ):
                    found_cloudflared = True

        assert found_cloudflared
