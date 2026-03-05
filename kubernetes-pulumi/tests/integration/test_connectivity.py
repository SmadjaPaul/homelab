import pytest
import requests
import socket
import os
from shared.apps.loader import AppLoader
from shared.utils.schemas import ExposureMode


def get_apps():
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    apps_yaml_path = os.path.join(project_root, "apps.yaml")
    loader = AppLoader(apps_yaml_path)
    return loader.load_for_cluster("oci")


@pytest.mark.parametrize(
    "app",
    [
        a
        for a in get_apps()
        if a.mode in [ExposureMode.PROTECTED, ExposureMode.PUBLIC] and a.hostname
    ],
)
def test_app_connectivity(app):
    """
    Test that the application's hostname resolves and is reachable.
    Since some are 'PROTECTED' (behind Authentik), we check for redirect or 200/401/302.
    Added a retry loop to handle DNS propagation (up to 5 minutes).
    """
    import time

    hostname = app.hostname
    max_attempts = 10
    delay = 30

    print(f"\nChecking connectivity for {app.name} at {hostname}...")

    for attempt in range(1, max_attempts + 1):
        try:
            print(f"  [Attempt {attempt}/{max_attempts}]")

            # 1. DNS Resolution Check
            try:
                ip = socket.gethostbyname(hostname)
                print(f"    [DNS] {hostname} resolved to {ip}")
            except socket.gaierror:
                raise Exception(f"DNS Resolution failed for {hostname}")

            # 2. HTTP Connectivity Check
            url = f"https://{hostname}"
            # We allow redirects and don't verify SSL strictly for the initial check (though we should)
            response = requests.get(url, timeout=10, allow_redirects=True, verify=False)
            print(f"    [HTTP] {url} returned status {response.status_code}")

            # If the app is protected, we expect a redirect to Authentik or a 401/302
            if app.mode == ExposureMode.PROTECTED:
                # Enforce: protected apps MUST redirect to authentik
                assert "authentik" in response.url or response.status_code in [
                    302,
                    401,
                ], (
                    f"Protected app {app.name} at {url} is accessible WITHOUT auth (status {response.status_code}, redirected to {response.url})"
                )

                print(f"    [INFO] {app.name} is correctly protected by Authentik")
            else:
                assert response.status_code < 400, (
                    f"App {app.name} is PUBLIC but returned status {response.status_code}"
                )

            # If we reached here, the test passed
            return

        except Exception as e:
            print(f"    [FAIL] Attempt {attempt} failed: {e}")
            if attempt < max_attempts:
                print(f"    [WAIT] Retrying in {delay}s...")
                time.sleep(delay)
            else:
                pytest.fail(
                    f"Connectivity test failed for {app.name} after {max_attempts} attempts: {e}"
                )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
