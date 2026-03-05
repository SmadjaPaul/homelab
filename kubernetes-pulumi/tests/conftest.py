"""
Pytest fixtures for Homelab V2 tests.
Automatically discovers apps from apps.yaml for dynamic test generation.
"""

import os
import sys
import pytest
from pathlib import Path
from typing import List

# Add PROJECT_ROOT to sys.path so 'shared' can be imported
PROJECT_ROOT = Path(__file__).parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

try:
    from shared.apps.loader import load_apps
    from shared.utils.schemas import AppModel, ExposureMode

    LOADER_AVAILABLE = True
except ImportError as e:
    LOADER_AVAILABLE = False

    # Define dummy classes to avoid NameErrors in type hints if imports fail
    class AppModel:
        pass

    class ExposureMode:
        pass

    ExposureMode.INTERNAL = "internal"

    print(f"Warning: Loader or Schemas not available for test discovery: {e}")

# --- Configuration ---


def get_cluster() -> str:
    """Determine cluster to test against."""
    cluster = os.environ.get("HOMELAB_CLUSTER")
    if cluster:
        return cluster

    # Check KUBECONFIG as fallback
    kubeconfig = os.environ.get("KUBECONFIG", "")
    if "oci" in kubeconfig.lower():
        return "oci"
    elif "local" in kubeconfig.lower():
        return "local"

    return "oci"  # Default


@pytest.fixture(scope="session")
def cluster() -> str:
    return get_cluster()


# --- Discovery Fixtures ---


@pytest.fixture(scope="session")
def all_apps(cluster: str) -> List[AppModel]:
    if not LOADER_AVAILABLE:
        pytest.skip("App loader not available")
    return load_apps(cluster)


@pytest.fixture(scope="session")
def apps_with_routing(all_apps: List[AppModel]) -> List[AppModel]:
    return [
        app
        for app in all_apps
        if app.test.test_routing and app.hostname and app.mode != ExposureMode.INTERNAL
    ]


@pytest.fixture(scope="session")
def apps_with_secrets(all_apps: List[AppModel]) -> List[AppModel]:
    return [app for app in all_apps if app.test.test_secrets and app.secrets]


@pytest.fixture(scope="session")
def apps_with_network_policy(all_apps: List[AppModel]) -> List[AppModel]:
    return [app for app in all_apps if app.test.test_network_policy]


# --- Parametrization Hook ---


def pytest_generate_tests(metafunc):
    """
    Dynamically generate tests based on app configuration.
    Pairs with 'test_case' argument in test functions.
    """
    if "test_case" in metafunc.fixturenames:
        cluster_name = get_cluster()
        apps = load_apps(cluster_name)

        # Determine filtering based on test name or module
        test_module = metafunc.module.__name__
        test_func_name = metafunc.function.__name__

        filtered_apps = apps

        if "routing" in test_module or "routing" in test_func_name:
            filtered_apps = [
                app
                for app in apps
                if app.test.test_routing
                and app.hostname
                and app.mode != ExposureMode.INTERNAL
            ]
        elif "secrets" in test_module or "secrets" in test_func_name:
            filtered_apps = [
                app for app in apps if app.test.test_secrets and app.secrets
            ]
        elif "network" in test_module or "network" in test_func_name:
            filtered_apps = [app for app in apps if app.test.test_network_policy]

        metafunc.parametrize("test_case", filtered_apps, ids=lambda app: app.name)


# --- Kubernetes Access ---


@pytest.fixture(scope="session")
def k8s_available() -> bool:
    """Check if kubectl can reach a cluster."""
    import subprocess

    try:
        subprocess.run(
            ["kubectl", "cluster-info"], capture_output=True, timeout=5, check=True
        )
        return True
    except Exception:
        return False
