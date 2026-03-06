"""
Integration test: Hetzner Storage Box Sub-account lifecycle.
Refactored into a native Pytest suite with cleanup logic.
"""

import os
import base64
import time
import subprocess
import requests
import pytest

HCLOUD_API = "https://api.hetzner.cloud/v1"
TEST_HOME_DIR = "pulumi-test-subaccount"
TEST_PASSWORD = "PulumiTest2026!"  # Meets Hetzner password policy


@pytest.fixture(scope="module")
def hcloud_token():
    token = os.environ.get("HCLOUD_TOKEN")
    if not token:
        pytest.skip("HCLOUD_TOKEN environment variable not set")
    return token


@pytest.fixture(scope="module")
def box_id():
    return os.environ.get("HETZNER_BOX_ID", "554589")


@pytest.fixture(scope="module")
def hetzner_subaccount(hcloud_token, box_id):
    """
    Fixture that creates a sub-account and ensures its deletion even if tests fail.
    """
    # 1. Create sub-account
    url = f"{HCLOUD_API}/storage_boxes/{box_id}/subaccounts"
    payload = {
        "description": "Pulumi integration test - Native Pytest Refactor",
        "home_directory": TEST_HOME_DIR,
        "password": TEST_PASSWORD,
        "access_settings": {
            "samba_enabled": True,
            "webdav_enabled": True,
            "ftp_enabled": True,
            "ssh_enabled": False,
            "reachable_externally": False,
        },
    }
    headers = {
        "Authorization": f"Bearer {hcloud_token}",
        "Content-Type": "application/json",
    }

    resp = requests.post(url, json=payload, headers=headers, timeout=15)
    if resp.status_code != 201:
        pytest.fail(f"Failed to create sub-account: {resp.status_code} {resp.text}")

    data = resp.json()
    sub = data["subaccount"]
    sub_id = sub["id"]
    username = sub["username"]
    server = sub["server"]

    # Give it a moment to propagate
    time.sleep(5)

    yield {
        "id": sub_id,
        "username": username,
        "password": TEST_PASSWORD,
        "server": server,
    }

    # 2. Cleanup: Delete sub-account
    del_url = f"{HCLOUD_API}/storage_boxes/{box_id}/subaccounts/{sub_id}"
    del_resp = requests.delete(del_url, headers=headers, timeout=15)
    if del_resp.status_code != 204:
        print(f"Warning: Cleanup failed for sub-account {sub_id}: {del_resp.text}")


def test_subaccount_exists_via_api(hetzner_subaccount, hcloud_token, box_id):
    """Verify the sub-account is visible via GET."""
    url = f"{HCLOUD_API}/storage_boxes/{box_id}/subaccounts/{hetzner_subaccount['id']}"
    headers = {"Authorization": f"Bearer {hcloud_token}"}
    resp = requests.get(url, headers=headers, timeout=15)
    assert resp.status_code == 200
    data = resp.json()
    assert data["subaccount"]["id"] == hetzner_subaccount["id"]


def test_webdav_connectivity(hetzner_subaccount):
    """Verify WebDAV (PROPFIND) returns 207 Multi-Status."""
    creds = base64.b64encode(
        f"{hetzner_subaccount['username']}:{hetzner_subaccount['password']}".encode()
    ).decode()
    url = f"https://{hetzner_subaccount['server']}/"
    headers = {
        "Authorization": f"Basic {creds}",
        "Depth": "0",
    }

    # WebDAV PROPFIND
    resp = requests.request("PROPFIND", url, headers=headers, timeout=15, verify=True)
    assert resp.status_code == 207


def test_ftp_connectivity(hetzner_subaccount):
    """Verify FTP listing works via curl."""
    result = subprocess.run(
        [
            "curl",
            "-sf",
            "--ftp-ssl",
            f"ftp://{hetzner_subaccount['server']}/",
            "--user",
            f"{hetzner_subaccount['username']}:{hetzner_subaccount['password']}",
            "--list-only",
            "--connect-timeout",
            "10",
        ],
        capture_output=True,
        text=True,
        timeout=15,
    )
    assert result.returncode == 0
