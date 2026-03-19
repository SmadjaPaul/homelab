"""
SSO injection tests for protected applications.

Architecture note:
  SSO in this homelab is handled by Authentik Outpost at the reverse-proxy layer.
  The Cloudflare Tunnel → Authentik Forward Auth Proxy intercepts every request
  before it reaches the application pod, so pods themselves do NOT need to declare
  Authentik-specific env vars for authentication to work.

  Apps are configured according to their provisioning.method:
    - proxy  : Authentik Outpost fully handles auth; the app receives forwarded
               headers (X-Authentik-*) transparently — no extra pod config needed.
    - header : App reads a specific header (e.g. WEBUI_AUTH_TRUSTED_EMAIL_HEADER)
               to identify the incoming user, so an env-var mapping IS expected.
    - oidc   : App performs its own OIDC flow with Authentik as the IdP;
               it requires a client_id and client_secret configured either in
               extra_env, secrets, or helm.values.
"""

import pytest
from shared.apps.loader import load_apps

APPS = load_apps("oci")


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------


def _has_oidc_like_key(key: str) -> bool:
    """Return True if a key looks related to OIDC / OAuth / SSO."""
    upper = key.upper()
    return any(tok in upper for tok in ("OIDC", "OAUTH", "SSO", "OPENID"))


# ---------------------------------------------------------------------------
# test_protected_apps_have_provisioning_method
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "app",
    [
        a
        for a in APPS
        if a.network.mode.value == "protected" and a.auth.provisioning is not None
    ],
    ids=lambda a: a.name,
)
def test_protected_apps_have_provisioning_method(app):
    """
    Every protected app that declares a provisioning block must have an explicit
    method.  A missing/None method means the YAML is incomplete and the app will
    not authenticate correctly.

    This replaces the old 'test_protected_apps_get_proxy_headers' test which
    incorrectly assumed that pods needed Authentik env vars.  In reality the
    Authentik Forward-Auth proxy injects headers at the network layer, so no
    pod-level env var is required for proxy-mode apps.
    """
    assert app.auth.provisioning.method is not None, (
        f"App '{app.name}' has a provisioning block but method is None. "
        "Set method to one of: proxy, header, oidc."
    )
    assert app.auth.provisioning.method.value in ("proxy", "header", "oidc", "none"), (
        f"App '{app.name}' has an unrecognised provisioning method: "
        f"'{app.auth.provisioning.method.value}'"
    )


# ---------------------------------------------------------------------------
# test_header_apps_have_header_env_var
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "app",
    [
        a
        for a in APPS
        if a.network.mode.value == "protected"
        and a.auth.provisioning is not None
        and a.auth.provisioning.method.value == "header"
    ],
    ids=lambda a: a.name,
)
def test_header_apps_have_header_env_var(app):
    """
    Apps with provisioning.method == 'header' rely on a specific HTTP header to
    identify the authenticated user (injected by Authentik Outpost).  They must
    expose at least one env var that names the expected header so the application
    knows which header to trust.

    Accepted patterns: any key containing HEADER, USER, REMOTE, or TRUSTED in
    extra_env or in helm.values (flat keys checked shallowly).
    """
    HEADER_PATTERNS = ("HEADER", "USER", "REMOTE", "TRUSTED")

    found = False

    # Check extra_env
    if app.extra_env:
        for key in app.extra_env:
            if any(pat in key.upper() for pat in HEADER_PATTERNS):
                found = True
                break

    # Check helm.values — scan both dict keys and list-item 'name' fields, since
    # app-template renders env vars as [{name: VAR_NAME, value: ...}] lists.
    if not found and app.helm and app.helm.values:

        def _scan(obj):
            if isinstance(obj, dict):
                # Check the 'name' field value (env-var list item pattern)
                name_val = obj.get("name", "")
                if isinstance(name_val, str) and any(
                    pat in name_val.upper() for pat in HEADER_PATTERNS
                ):
                    return True
                for k, v in obj.items():
                    if isinstance(k, str) and any(
                        pat in k.upper() for pat in HEADER_PATTERNS
                    ):
                        return True
                    if isinstance(v, (dict, list)) and _scan(v):
                        return True
            elif isinstance(obj, list):
                for item in obj:
                    if _scan(item):
                        return True
            return False

        found = _scan(app.helm.values)

    assert found, (
        f"App '{app.name}' uses auth.provisioning.method='header' but no header-mapping "
        "env var was found in extra_env or helm.values. "
        "Expected a key containing HEADER, USER, REMOTE, or TRUSTED."
    )


# ---------------------------------------------------------------------------
# test_oidc_apps_have_oidc_config
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "app",
    [
        a
        for a in APPS
        if a.network.mode.value == "protected"
        and a.auth.provisioning is not None
        and a.auth.provisioning.method.value == "oidc"
    ],
    ids=lambda a: a.name,
)
def test_oidc_apps_have_oidc_config(app):
    """
    Apps with provisioning.method == 'oidc' must supply their own OIDC client
    credentials.  The accepted key names are intentionally broad to accommodate
    app-specific conventions:

      - Standard : OIDC_CLIENT_ID / OIDC_CLIENT_SECRET
      - Vaultwarden : SSO_CLIENT_ID / SSO_CLIENT_SECRET
      - ownCloud : PROXY_OIDC_CLIENT_ID / PROXY_OIDC_CLIENT_SECRET
      - open-webui : WEBUI_AUTH (flag) + client_id in provisioning block

    The test accepts any of the following as evidence of OIDC configuration:
      1. A key matching OIDC/OAUTH/SSO in extra_env.
      2. A key matching OIDC/OAUTH/SSO in a declared secret's keys.
      3. A key matching OIDC/OAUTH/SSO in auto_secrets.
      4. A client_id set in the provisioning block (convention-based flow).
      5. A key matching OIDC/OAUTH/SSO anywhere in helm.values (shallow scan).

    This replaces the old test which only checked extra_env and secrets, causing
    false negatives for apps that embed their client config inside helm.values or
    rely on the provisioning.client_id convention.
    """
    # 1. Check extra_env
    if app.extra_env:
        for key in app.extra_env:
            if _has_oidc_like_key(key):
                return  # pass

    # 2. Check declared secrets keys
    if app.secrets:
        for secret in app.secrets:
            for key in (
                secret.keys if isinstance(secret.keys, list) else secret.keys.keys()
            ):
                if _has_oidc_like_key(key):
                    return  # pass

    # 3. Check auto_secrets keys
    if app.auto_secrets:
        for _secret_name, env_map in app.auto_secrets.items():
            for key in env_map:
                if _has_oidc_like_key(key):
                    return  # pass

    # 4. Check auth.provisioning.client_id (convention-based — Authentik registry uses it)
    if app.auth.provisioning and app.auth.provisioning.client_id:
        return  # pass

    # 5. Shallow scan of helm.values
    def _scan_values(obj) -> bool:
        if isinstance(obj, dict):
            for k, v in obj.items():
                if isinstance(k, str) and _has_oidc_like_key(k):
                    return True
                if isinstance(v, str) and _has_oidc_like_key(v):
                    return True
                if isinstance(v, (dict, list)) and _scan_values(v):
                    return True
        elif isinstance(obj, list):
            for item in obj:
                if isinstance(item, dict):
                    name_val = item.get("name", "")
                    if isinstance(name_val, str) and _has_oidc_like_key(name_val):
                        return True
                    if _scan_values(item):
                        return True
        return False

    if app.helm and app.helm.values and _scan_values(app.helm.values):
        return  # pass

    pytest.fail(
        f"App '{app.name}' is configured for OIDC (auth.provisioning.method='oidc') but "
        "no OIDC/OAuth/SSO configuration was found in extra_env, secrets, "
        "auto_secrets, auth.provisioning.client_id, or helm.values. "
        "Add the appropriate client credentials."
    )


# ---------------------------------------------------------------------------
# test_oidc_client_id_consistency
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "app",
    [
        a
        for a in APPS
        if a.auth.provisioning is not None
        and a.auth.provisioning.method.value == "oidc"
        and a.auth.provisioning.client_id is not None
    ],
    ids=lambda a: a.name,
)
def test_oidc_client_id_consistency(app):
    """
    Verify that the client_id declared in the provisioning block matches the
    client_id used by the application in extra_env.
    """
    client_id = app.auth.provisioning.client_id

    # Map of app name to the env var name that should contain the client_id
    env_map = {
        "owncloud": "PROXY_OIDC_CLIENT_ID",
        "vaultwarden": "SSO_CLIENT_ID",
        "audiobookshelf": "OIDC_CLIENT_ID",
        "open-webui": "PROXY_OIDC_CLIENT_ID",  # If used
    }

    env_var = env_map.get(app.name)
    if env_var and app.extra_env and env_var in app.extra_env:
        actual = app.extra_env[env_var]
        assert actual == client_id, (
            f"Consistency error for {app.name}: auth.provisioning.client_id='{client_id}' "
            f"but extra_env.{env_var}='{actual}'"
        )
