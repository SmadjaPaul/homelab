import pulumi
import pulumi_kubernetes as k8s
from shared.apps.common.registry import AppRegistry
from shared.utils.schemas import AppModel, ExposureMode, AppCategory


class MyMocks(pulumi.runtime.Mocks):
    def new_resource(self, args: pulumi.runtime.MockResourceArgs):
        return [args.name, dict(args.inputs)]

    def call(self, args: pulumi.runtime.MockCallArgs):
        return {}


pulumi.runtime.set_mocks(MyMocks())


@pulumi.runtime.test
def test_ingress_serialization():
    # Arrange
    app = AppModel(
        name="testapp",
        namespace="testns",
        mode=ExposureMode.PUBLIC,
        category=AppCategory.PUBLIC,
        auth=True,
    )

    # Create a dummy provider
    provider = k8s.Provider("provider", kubeconfig="{}")
    registry = AppRegistry(
        "test-registry", provider, config={"domain": "test-domain.dev"}
    )

    # Act
    # We call the method that creates the Ingress (returns List[Resource])
    ingresses = registry._create_tunnel_ingress(app, None)
    ingress = ingresses[0]

    # Assert
    def check_annotations(m):
        annotations = m.annotations if hasattr(m, "annotations") else {}
        # Verify that the auth-signin annotation was correctly serialized and does not contain the Output string
        auth_signin = annotations.get("nginx.ingress.kubernetes.io/auth-signin", "")
        assert "Calling __str__ on an Output[T]" not in auth_signin
        # The expected format is https://auth.test-domain.dev/outpost.goauthentik.io/start?rd=$escaped_request_uri
        assert (
            "https://auth.test-domain.dev/outpost.goauthentik.io/start?rd=$escaped_request_uri"
            == auth_signin
        )

    # Pulumi outputs resolve asynchronously in tests, so we use apply to assert
    return ingress.metadata.apply(check_annotations)
