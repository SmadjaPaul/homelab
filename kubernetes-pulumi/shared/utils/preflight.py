"""
Preflight validation for apps.yaml configuration.

Runs before deployment to catch configuration errors early.
Called from AppLoader.load() after parsing and convention resolution.

RELATED FILES:
  - shared/apps/loader.py: Calls validate_all() after loading apps
  - shared/utils/schemas.py: AppModel, ExposureMode — Pydantic models
  - apps.yaml: The configuration being validated
"""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from shared.utils.schemas import AppModel

from shared.utils.schemas import ExposureMode


# Apps whose OIDC is configured via their UI, not environment variables.
# The Authentik provider is still created, but env var injection is skipped.
UI_ONLY_OIDC = {"immich", "audiobookshelf", "nextcloud"}


def validate_all(apps: list[AppModel], domain: str) -> list[str]:
    """
    Validate all apps for configuration consistency.

    Returns a list of error messages. Empty list means all validations passed.
    """
    errors: list[str] = []
    hostnames_seen: dict[str, str] = {}

    for app in apps:
        errors.extend(_validate_networking(app, hostnames_seen))
        errors.extend(_validate_storage(app))
        errors.extend(_validate_database(app))
        errors.extend(_validate_sso(app))

    return errors


def _validate_networking(app: AppModel, hostnames_seen: dict[str, str]) -> list[str]:
    """Validate networking configuration."""
    errors: list[str] = []

    # Rule 1: Exposed apps need a hostname
    if app.network.mode in (ExposureMode.PROTECTED, ExposureMode.PUBLIC):
        if not app.network.hostname:
            errors.append(
                f"{app.name}: mode={app.network.mode.value} but hostname is None. "
                f"Set 'hostname_prefix' in apps.yaml."
            )

    # Rule 6: Hostname uniqueness
    hostname = app.network.hostname
    if hostname:
        if hostname in hostnames_seen:
            errors.append(
                f"{app.name}: hostname '{hostname}' conflicts "
                f"with '{hostnames_seen[hostname]}'"
            )
        hostnames_seen[hostname] = app.name

    return errors


def _validate_storage(app: AppModel) -> list[str]:
    """Validate storage configuration."""
    errors: list[str] = []

    # Rule 2: hetzner-smb requires existing_claim
    for s in app.persistence.storage or []:
        if getattr(s, "storage_class", None) == "hetzner-smb":
            if not getattr(s, "existing_claim", None):
                errors.append(
                    f"{app.name}.storage.{s.name}: storage_class='hetzner-smb' "
                    f"requires 'existing_claim'. Create the PVC in k8s-storage first."
                )

    return errors


def _validate_database(app: AppModel) -> list[str]:
    """Validate database configuration consistency."""
    errors: list[str] = []

    # Rule 5: database.local: true → requires: [postgres]
    if app.persistence.database and app.persistence.database.local:
        if "postgres" not in app.requires:
            errors.append(
                f"{app.name}: database.local=true but 'postgres' not in requires. "
                f"Add 'postgres' to the requires list."
            )

    return errors


def _validate_sso(app: AppModel) -> list[str]:
    """Validate SSO configuration."""
    errors: list[str] = []

    # Rule 3: OIDC apps should have redirect URIs defined
    # (Warning only — some apps use convention-based URIs from authentik_registry)
    if app.auth.sso == "authentik-oidc" and app.name not in UI_ONLY_OIDC:
        if not app.network.hostname:
            errors.append(
                f"{app.name}: sso=authentik-oidc but no hostname. "
                f"OIDC requires a reachable hostname for redirect URIs."
            )

    return errors
