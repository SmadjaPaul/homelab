from shared.utils.schemas import (
    AppModel,
    AppHelmConfig,
    AppNetworkConfig,
    AppAuthConfig,
    AppPersistenceConfig,
    DatabaseConfig,
    ExposureMode,
)
from shared.apps.adapters import AppTemplateAdapter


def test_app_template_adapter_service_mapping():
    """Verify that port from AppNetworkConfig is correctly mapped to service.main.ports.http."""
    model = AppModel(
        name="test-app",
        namespace="test-ns",
        network=AppNetworkConfig(hostname="test.example.com", port=9000),
        helm=AppHelmConfig(
            chart="app-template",
            repo="https://bjw-s-labs.github.io/helm-charts",
            version="3.2.1",
            values={
                "controllers": {
                    "main": {
                        "containers": {
                            "main": {
                                "image": {
                                    "repository": "docker.io/library/nginx",
                                    "tag": "latest",
                                }
                            }
                        }
                    }
                }
            },
        ),
    )
    adapter = AppTemplateAdapter(model)
    values = adapter.get_final_values()

    assert values["service"]["main"]["ports"]["http"]["port"] == 9000


def test_app_template_adapter_db_injection():
    """Verify that database config triggers environment variable injection."""
    # Use a real image to pass validation
    model = AppModel(
        name="test-app",
        namespace="test-ns",
        persistence=AppPersistenceConfig(database=DatabaseConfig(local=True)),
        helm=AppHelmConfig(
            chart="app-template",
            repo="...",
            version="...",
            values={
                "controllers": {
                    "main": {
                        "containers": {
                            "main": {
                                "image": {
                                    "repository": "docker.io/library/postgres",
                                    "tag": "latest",
                                }
                            }
                        }
                    }
                }
            },
        ),
    )
    adapter = AppTemplateAdapter(model)
    values = adapter.get_final_values()

    env = values["controllers"]["main"]["containers"]["main"]["env"]
    # Check that POSTGRES_HOST is injected (default prefix)
    assert any(e["name"] == "POSTGRES_HOST" for e in env)
    assert any(e["name"] == "POSTGRES_DB" for e in env)


def test_app_template_adapter_sso_injection():
    """Verify that SSO config triggers environment variable injection in app-template."""
    model = AppModel(
        name="test-app",
        namespace="test-ns",
        auth=AppAuthConfig(sso="authentik-header"),
        network=AppNetworkConfig(
            hostname="test.example.com", mode=ExposureMode.PROTECTED
        ),
        helm=AppHelmConfig(
            chart="app-template",
            repo="...",
            version="...",
            values={
                "controllers": {
                    "main": {
                        "containers": {
                            "main": {
                                "image": {
                                    "repository": "docker.io/library/nginx",
                                    "tag": "latest",
                                }
                            }
                        }
                    }
                }
            },
        ),
    )
    adapter = AppTemplateAdapter(model)
    values = adapter.get_final_values()

    env = values["controllers"]["main"]["containers"]["main"]["env"]
    # Header SSO should inject generic headers
    assert any(e["name"] == "HTTP_X_REMOTE_USER" for e in env)
    assert any(e["name"] == "AUTH_HEADER" for e in env)
