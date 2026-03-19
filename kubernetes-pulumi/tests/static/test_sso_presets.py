from shared.apps.sso_presets import resolve_sso
from shared.utils.schemas import AppModel, AppTier, AppCategory, ExposureMode


def create_mock_app(name: str, sso: str = "authentik-oidc"):
    return AppModel(
        name=name,
        category=AppCategory.PROTECTED,
        tier=AppTier.STANDARD,
        namespace="test",
        port=80,
        hostname_prefix=name,
        mode=ExposureMode.PROTECTED,
        clusters=["oci"],
        sso=sso,
    )


def test_nextcloud_ui_only_oidc():
    """Nextcloud is in UI_ONLY_OIDC: Authentik provider is created but NO env vars injected."""
    app = create_mock_app("nextcloud")
    resolve_sso(app, "example.com")

    assert app.auth.enabled is True
    assert app.auth.provisioning is not None
    assert app.auth.provisioning.client_id == "nextcloud-oidc"
    # UI_ONLY_OIDC apps do NOT get env vars — OIDC is configured in the app UI
    assert "OIDC_LOGIN_PROVIDER_URL" not in app.extra_env
    assert "OIDC_ISSUER_URL" not in app.extra_env


def test_immich_ui_only_oidc():
    """Immich is in UI_ONLY_OIDC: Authentik provider is created but NO env vars injected."""
    app = create_mock_app("immich")
    resolve_sso(app, "example.com")

    assert app.auth.enabled is True
    assert app.auth.provisioning is not None
    assert app.auth.provisioning.client_id == "immich-oidc"
    # UI_ONLY_OIDC apps do NOT get env vars
    assert "OAUTH_ENABLED" not in app.extra_env
    assert "OIDC_ISSUER_URL" not in app.extra_env


def test_romm_sso_preset():
    app = create_mock_app("romm")
    resolve_sso(app, "example.com")

    assert app.auth.enabled is True
    assert app.extra_env["OIDC_ENABLED"] == "true"
    assert app.extra_env["OIDC_PROVIDER"] == "authentik"
    assert (
        app.extra_env["OIDC_SERVER_APPLICATION_URL"]
        == "https://auth.example.com/application/o/romm-oidc/"
    )


def test_vaultwarden_sso_preset():
    app = create_mock_app("vaultwarden")
    resolve_sso(app, "example.com")

    assert app.auth.enabled is True
    assert app.extra_env["SSO_ENABLED"] == "true"
    assert (
        app.extra_env["SSO_AUTHORITY"]
        == "https://auth.example.com/application/o/vaultwarden-oidc/"
    )
    assert app.extra_env["SSO_SCOPES"] == "openid email profile offline_access"


def test_open_webui_sso_preset():
    """Open-WebUI uses OIDC with custom env vars (OAUTH_CLIENT_ID, OPENID_PROVIDER_URL)."""
    app = create_mock_app("open-webui")
    resolve_sso(app, "example.com")

    assert app.auth.enabled is True
    assert app.extra_env["OAUTH_CLIENT_ID"] == "open-webui-oidc"
    assert "OPENID_PROVIDER_URL" in app.extra_env
    assert app.extra_env["ENABLE_OAUTH_SIGNUP"] == "true"


def test_header_preset_navidrome():
    app = create_mock_app("navidrome", sso="authentik-header")
    resolve_sso(app, "example.com")

    assert app.auth.enabled is True
    assert app.extra_env["ND_EXTAUTH_USERHEADER"] == "X-authentik-username"
    assert (
        app.extra_env["ND_EXTAUTH_TRUSTEDSOURCES"]
        == "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
    )
    assert "ND_REVERSEPROXYUSERHEADER" not in app.extra_env
