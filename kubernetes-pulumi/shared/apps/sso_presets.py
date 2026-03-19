def resolve_sso(app, domain: str):
    """Resolve SSO preset into auth flag, provisioning config, and extra_env."""
    if not app.auth.sso:
        return

    app.auth.enabled = True

    if app.auth.sso == "authentik-oidc":
        _resolve_oidc(app, domain)
    elif app.auth.sso == "authentik-header":
        _resolve_header(app)


def _resolve_oidc(app, domain: str):
    from shared.utils.schemas import ProvisioningConfig, ProvisioningMethod

    oidc_slug = f"{app.name}-oidc"

    if not app.auth.provisioning:
        app.auth.provisioning = ProvisioningConfig(
            method=ProvisioningMethod.OIDC, client_id=oidc_slug
        )
    elif not app.auth.provisioning.client_id:
        app.auth.provisioning.client_id = oidc_slug
    issuer = f"https://auth.{domain}/application/o/{oidc_slug}/"

    sso_env = {
        "OIDC_ISSUER_URL": issuer,
        "OIDC_CLIENT_ID": app.auth.provisioning.client_id or oidc_slug,
    }

    # Apps whose OIDC is configured via UI only — don't inject env vars.
    # The Authentik provider is still created, but the app reads its config
    # from its own UI/settings, not from environment variables.
    UI_ONLY_OIDC = {"immich", "audiobookshelf", "nextcloud"}

    APP_OIDC_OVERRIDES = {
        "vaultwarden": lambda issuer, cid: {
            "SSO_ENABLED": "true",
            "SSO_AUTHORITY": issuer,
            "SSO_CLIENT_ID": cid,
            "SSO_SCOPES": "openid email profile offline_access",
        },
        "open-webui": lambda issuer, cid: {
            "OAUTH_CLIENT_ID": cid,
            "OPENID_PROVIDER_URL": f"{issuer}.well-known/openid-configuration",
            "ENABLE_OAUTH_SIGNUP": "true",
            "OAUTH_PROVIDER_NAME": "Authentik",
        },
        "romm": lambda issuer, cid: {
            "OIDC_ENABLED": "true",
            "OIDC_PROVIDER": "authentik",
            "OIDC_CLIENT_ID": cid,
            "OIDC_SERVER_APPLICATION_URL": issuer,
            "OIDC_REDIRECT_URI": f"https://romm.{domain}/api/oauth2/openid/callback",
        },
    }

    # Skip env injection for UI-only apps (provider is still created in Authentik)
    if app.name in UI_ONLY_OIDC:
        return

    override_fn = APP_OIDC_OVERRIDES.get(app.name)
    if override_fn:
        sso_env.update(override_fn(issuer, sso_env["OIDC_CLIENT_ID"]))

    for k, v in sso_env.items():
        if k not in app.extra_env:
            app.extra_env[k] = v


def _resolve_header(app):
    from shared.utils.schemas import ProvisioningConfig, ProvisioningMethod

    if not app.auth.provisioning:
        app.auth.provisioning = ProvisioningConfig(method=ProvisioningMethod.HEADER)

    APP_HEADER_OVERRIDES = {
        "navidrome": {
            "ND_EXTAUTH_USERHEADER": "X-authentik-username",
            "ND_EXTAUTH_TRUSTEDSOURCES": "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16",
        },
        "paperless-ngx": {
            "AUTH_HEADER": "X-authentik-username",
            "HTTP_X_REMOTE_USER": "X-authentik-username",
            "PAPERLESS_REMOTE_USER_SET_NAME": "true",
            "PAPERLESS_REMOTE_USER_SET_EMAIL": "true",
            "PAPERLESS_ENABLE_HTTP_REMOTE_USER": "true",
            "PAPERLESS_ENABLE_HTTP_REMOTE_USER_API": "true",
            "PAPERLESS_HTTP_REMOTE_USER_HEADER_NAME": "HTTP_X_AUTHENTIK_USERNAME",
        },
    }

    header_env = APP_HEADER_OVERRIDES.get(
        app.name,
        {
            "AUTH_HEADER": "X-authentik-username",
            "HTTP_X_REMOTE_USER": "X-authentik-username",
        },
    )

    for k, v in header_env.items():
        if k not in app.extra_env:
            app.extra_env[k] = v
