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


def test_image_repositories(apps_config):
    """
    Validate that image repositories in apps.yaml don't contain bad patterns
    like `docker.io/docker.io/` or other malformed registry prefixes.
    """
    invalid_patterns = ["docker.io/docker.io/", "ghcr.io/ghcr.io/", "quay.io/quay.io/"]

    for app_data in apps_config:
        try:
            app = AppModel(**app_data)
        except Exception:
            continue

        # Check Helm values if they contain image definitions
        if app.helm and app.helm.values:
            _check_dict_for_images(app.helm.values, app.name, invalid_patterns)


def _check_dict_for_images(data_dict: dict, app_name: str, invalid_patterns: list):
    """Recursively search for 'image' keys and validate their 'repository' values."""
    if not isinstance(data_dict, dict):
        return

    for k, v in data_dict.items():
        if k == "image" and isinstance(v, dict):
            repo = v.get("repository", "")
            if isinstance(repo, str):
                for pattern in invalid_patterns:
                    if pattern in repo:
                        pytest.fail(
                            f"App '{app_name}' has an invalid image repository pattern '{pattern}' in '{repo}'"
                        )
        elif isinstance(v, dict):
            _check_dict_for_images(v, app_name, invalid_patterns)
        elif isinstance(v, list):
            for item in v:
                if isinstance(item, dict):
                    _check_dict_for_images(item, app_name, invalid_patterns)
