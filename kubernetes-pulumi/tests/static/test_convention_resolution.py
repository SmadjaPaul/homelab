from shared.apps.loader import resolve_conventions
from shared.utils.schemas import (
    AppModel,
    ExposureMode,
    SecretRequirement,
    DatabaseConfig,
)


def test_hostname_auto_derivation():
    domain = "example.com"
    apps = [AppModel(name="test-app", hostname_prefix="test")]
    resolve_conventions(apps, domain)
    assert apps[0].network.hostname == "test.example.com"


def test_implicit_dependencies_secrets():
    apps = [
        AppModel(
            name="test-app",
            secrets=[SecretRequirement(name="test-secret", keys=["key"])],
        )
    ]
    resolve_conventions(apps, "example.com")
    assert "external-secrets" in apps[0].dependencies


def test_implicit_dependencies_exposure():
    apps = [
        AppModel(name="test-app", hostname="test.example.com", mode=ExposureMode.PUBLIC)
    ]
    resolve_conventions(apps, "example.com")
    assert "cloudflared" in apps[0].dependencies
    assert "kube-system" in apps[0].dependencies


def test_implicit_dependencies_database():
    apps = [AppModel(name="test-app", database=DatabaseConfig(local=True))]
    resolve_conventions(apps, "example.com")
    assert "cnpg-system" in apps[0].dependencies


def test_combined_conventions():
    domain = "smadja.dev"
    apps = [
        AppModel(
            name="paperless",
            hostname_prefix="paperless",
            mode=ExposureMode.PROTECTED,
            database=DatabaseConfig(local=True),
            secrets=[SecretRequirement(name="paperless-secrets", keys=["key"])],
        )
    ]
    resolve_conventions(apps, domain)
    assert apps[0].network.hostname == "paperless.smadja.dev"
    assert "external-secrets" in apps[0].dependencies
    assert "cloudflared" in apps[0].dependencies
    assert "kube-system" in apps[0].dependencies
    assert "cnpg-system" in apps[0].dependencies


def test_requires_postgres():
    apps = [AppModel(name="test-app", requires=["postgres"])]
    resolve_conventions(apps, "example.com")
    assert apps[0].persistence.database is not None
    assert apps[0].persistence.database.local is True
    assert "cnpg-system" in apps[0].dependencies


# --- SSO Preset Tests ---


def test_sso_oidc_base():
    """authentik-oidc preset injects OIDC env vars, sets auth=True, and sets client_id in provisioning."""
    apps = [AppModel(name="myapp", sso="authentik-oidc")]
    resolve_conventions(apps, "example.com")
    app = apps[0]
    assert app.auth.enabled is True
    assert app.auth.provisioning is not None
    assert app.auth.provisioning.client_id == "myapp-oidc"
    assert (
        app.extra_env["OIDC_ISSUER_URL"]
        == "https://auth.example.com/application/o/myapp-oidc/"
    )
    assert app.extra_env["OIDC_CLIENT_ID"] == "myapp-oidc"
    assert "authentik" in app.dependencies


def test_sso_oidc_vaultwarden():
    """Vaultwarden OIDC preset adds SSO_ENABLED, SSO_AUTHORITY, SSO_CLIENT_ID."""
    apps = [AppModel(name="vaultwarden", sso="authentik-oidc")]
    resolve_conventions(apps, "smadja.dev")
    app = apps[0]
    assert app.auth.enabled is True
    assert app.extra_env["SSO_ENABLED"] == "true"
    assert (
        app.extra_env["SSO_AUTHORITY"]
        == "https://auth.smadja.dev/application/o/vaultwarden-oidc/"
    )
    assert app.extra_env["SSO_CLIENT_ID"] == "vaultwarden-oidc"
    assert (
        app.extra_env["OIDC_ISSUER_URL"]
        == "https://auth.smadja.dev/application/o/vaultwarden-oidc/"
    )


def test_sso_header_generic():
    """authentik-header preset injects AUTH_HEADER for generic apps."""
    apps = [AppModel(name="someapp", sso="authentik-header")]
    resolve_conventions(apps, "example.com")
    app = apps[0]
    assert app.auth.enabled is True
    assert app.extra_env["AUTH_HEADER"] == "X-authentik-username"
    assert app.extra_env["HTTP_X_REMOTE_USER"] == "X-authentik-username"
    assert "authentik" in app.dependencies


def test_sso_header_navidrome():
    """Navidrome header preset uses ND_EXTAUTH_USERHEADER (new ExtAuth API)."""
    apps = [AppModel(name="navidrome", sso="authentik-header")]
    resolve_conventions(apps, "example.com")
    app = apps[0]
    assert app.auth.enabled is True
    assert app.extra_env["ND_EXTAUTH_USERHEADER"] == "X-authentik-username"
    assert "ND_REVERSEPROXYUSERHEADER" not in app.extra_env
    assert "AUTH_HEADER" not in app.extra_env


def test_sso_does_not_override_explicit_env():
    """Explicit extra_env in AppModel is not overridden by SSO presets."""
    apps = [
        AppModel(
            name="myapp",
            sso="authentik-oidc",
            extra_env={"OIDC_CLIENT_ID": "my-custom-id"},
        )
    ]
    resolve_conventions(apps, "example.com")
    app = apps[0]
    assert app.extra_env["OIDC_CLIENT_ID"] == "my-custom-id"
    assert "OIDC_ISSUER_URL" in app.extra_env


def test_sso_oidc_preserves_explicit_provisioning():
    """Explicit provisioning config is not overridden by SSO presets."""
    from shared.utils.schemas import ProvisioningConfig, ProvisioningMethod

    apps = [
        AppModel(
            name="myapp",
            sso="authentik-oidc",
            provisioning=ProvisioningConfig(
                method=ProvisioningMethod.OIDC, client_id="custom-client"
            ),
        )
    ]
    resolve_conventions(apps, "example.com")
    app = apps[0]
    assert app.auth.provisioning.client_id == "custom-client"
    assert app.extra_env["OIDC_CLIENT_ID"] == "custom-client"
