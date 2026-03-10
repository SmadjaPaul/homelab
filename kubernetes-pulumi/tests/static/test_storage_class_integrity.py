import pytest
import yaml
import sys
from pathlib import Path

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).parent.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from shared.utils.schemas import AppModel  # noqa: E402

APPS_YAML_PATH = Path(__file__).parent.parent.parent / "apps.yaml"


@pytest.fixture
def apps_config():
    with open(APPS_YAML_PATH, "r") as f:
        return yaml.safe_load(f)


def test_storage_class_integrity(apps_config):
    """
    Validate that any persistence enabled in apps.yaml explicitly sets
    a valid storageClass (e.g. oci-bv) to avoid 'FailedBinding' errors.
    """
    valid_storage_classes = ["oci-bv", "fss"]  # Add others if supported

    for app_data in apps_config:
        try:
            app = AppModel(**app_data)
        except Exception:
            continue

        # 1. Check old 'storage' top-level array
        if app.storage:
            for vol in app.storage:
                # The old storage array doesn't currently define storageClass in our schema
                # But if it did, we'd check it here. It relies on default storage class.
                pass

        # 2. Check helm values for persistence
        if app.helm and app.helm.values:
            _check_persistence_for_storageclass(
                app.helm.values, app.name, valid_storage_classes
            )


def _check_persistence_for_storageclass(
    data_dict: dict, app_name: str, valid_storage_classes: list, path: str = ""
):
    """Recursively search for 'persistence' toggles and validate 'storageClass'."""
    if not isinstance(data_dict, dict):
        return

    for k, v in data_dict.items():
        current_path = f"{path}.{k}" if path else k

        # If we find a block that looks like a PVC definition with enabled=true
        if isinstance(v, dict) and v.get("enabled", False) is True:
            # Does it have accessMode and size? (typical persistence definitions)
            if "size" in v or "accessMode" in v:
                sc = v.get("storageClass")
                if not sc:
                    pytest.fail(
                        f"App '{app_name}' missing explicit 'storageClass' at '{current_path}'. "
                        f"Must be one of {valid_storage_classes} to prevent binding issues."
                    )
                elif sc not in valid_storage_classes:
                    pytest.fail(
                        f"App '{app_name}' uses invalid 'storageClass: {sc}' at '{current_path}'. "
                        f"Must be one of {valid_storage_classes}"
                    )

        if isinstance(v, dict):
            _check_persistence_for_storageclass(
                v, app_name, valid_storage_classes, current_path
            )
        elif isinstance(v, list):
            for i, item in enumerate(v):
                if isinstance(item, dict):
                    _check_persistence_for_storageclass(
                        item, app_name, valid_storage_classes, f"{current_path}[{i}]"
                    )
