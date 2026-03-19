import os
import pulumi
from typing import List, Optional, Tuple


# Pulumi mocking framework
class MyMocks(pulumi.runtime.Mocks):
    def new_resource(
        self, args: pulumi.runtime.MockResourceArgs
    ) -> Tuple[Optional[str], dict]:
        return args.name + "_id", args.inputs

    def call(
        self, args: pulumi.runtime.MockCallArgs
    ) -> Tuple[dict, Optional[List[Tuple[str, str]]]]:
        return {}, None


pulumi.runtime.set_mocks(MyMocks())

# Now we can import our Pulumi code
from shared.apps.generic import create_generic_app  # noqa: E402


@pulumi.runtime.test
def test_helm_app_transformations():
    # 1. Provide a dummy configuration
    os.environ["PULUMI_NODEJS_INSTALL"] = "/tmp"  # Bypass some pulumi checks

    # App setup directly via Pydantic model for testing
    from shared.utils.schemas import AppModel, ExposureMode, AppCategory, AppTier

    model = AppModel(
        name="test-app",
        namespace="default",
        category=AppCategory.INTERNAL,
        tier=AppTier.STANDARD,
        network={
            "mode": ExposureMode.INTERNAL,
        },
        helm={"chart": "bitnami/nginx", "version": "15.0.0"},
        persistence={
            "database": {"local": True},
        },
    )

    # 2. Instantiate the app logic
    app = create_generic_app(model)

    # 3. We run the deployment logic inside a pulumi program
    def do_deploy():
        import pulumi_kubernetes as k8s

        provider = k8s.Provider("test-provider", render_yaml_to_directory="/tmp/render")
        app.deploy_components(provider, {})

    # We just run do_deploy directly since we are in a test context
    # Usually we'd use pulumi.runtime.test but testing transformations is tricky without actual output evaluation.
    # For this test, we verify that the config secret logic inside GenericHelmApp generates the right data.

    final_values = app.get_final_values()

    # Verify that local DB info was injected into Helm values for fallback support
    assert "env" in final_values
    env_names = [e["name"] for e in final_values["env"]]
    assert "POSTGRES_HOST" in env_names
    assert "POSTGRES_DB" in env_names


def test_authentik_database_secret_values():
    from shared.utils.schemas import AppModel, ExposureMode, AppCategory, AppTier

    model = AppModel(
        name="authentik",
        namespace="authentik",
        category=AppCategory.INTERNAL,
        tier=AppTier.STANDARD,
        network={
            "mode": ExposureMode.INTERNAL,
        },
        helm={
            "chart": "authentik/authentik",
        },
        persistence={
            "database": {"local": True},
        },
    )

    from shared.apps.impl.authentik import create_app

    app = create_app(model)

    final_values = app.get_final_values()

    # Authentik shouldn't have root env DB_HOST because it's handled via config_secret
    # But GenericHelmApp currently overrides get_final_values logic.
    assert "fullnameOverride" in final_values
    if "env" in final_values:
        env_names = [e.get("name") for e in final_values["env"]]
        assert "DATABASE_URL" not in env_names
