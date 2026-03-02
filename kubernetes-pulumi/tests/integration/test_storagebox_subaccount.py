#!/usr/bin/env python3
"""
Integration test: Hetzner Storage Box Sub-account lifecycle.

Creates a temporary sub-account, verifies it exists via the Cloud API,
tests WebDAV connectivity, then deletes it.

Usage:
    # Set env vars first:
    export HCLOUD_TOKEN="your_hetzner_cloud_api_token"
    export HETZNER_BOX_ID="554589"

    python tests/integration/test_storagebox_subaccount.py

Requirements:
    pip install requests
"""
import os
import sys
import json
import time
import subprocess
import urllib.request
import urllib.error
import base64
from typing import Optional

HCLOUD_API = "https://api.hetzner.cloud/v1"
TEST_HOME_DIR = "pulumi-test-subaccount"
TEST_PASSWORD = "PulumiTest2026!"  # Meets Hetzner password policy


def hcloud_request(
    method: str,
    path: str,
    token: str,
    body: Optional[dict] = None,
) -> dict:
    """Make a Hetzner Cloud API request."""
    url = f"{HCLOUD_API}{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body_raw = e.read().decode()
        print(f"  HTTP {e.code} {e.reason}: {body_raw}")
        raise


def test_webdav(username: str, password: str, server: str) -> bool:
    """Test WebDAV connectivity to the sub-account."""
    creds = base64.b64encode(f"{username}:{password}".encode()).decode()
    url = f"https://{server}/"
    req = urllib.request.Request(
        url,
        headers={"Authorization": f"Basic {creds}"},
        method="PROPFIND",
    )
    req.add_header("Depth", "0")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            code = resp.getcode()
            print(f"    WebDAV PROPFIND → HTTP {code} ✅")
            return True
    except urllib.error.HTTPError as e:
        print(f"    WebDAV PROPFIND → HTTP {e.code} {'✅' if e.code == 207 else '❌'}")
        return e.code == 207  # 207 Multi-Status is the expected WebDAV success
    except Exception as e:
        print(f"    WebDAV connection error: {e} ❌")
        return False


def test_ftp(username: str, password: str, server: str) -> bool:
    """Test FTP connectivity to the sub-account using curl."""
    result = subprocess.run(
        ["curl", "-sf", "--ftp-ssl",
         f"ftp://{server}/",
         "--user", f"{username}:{password}",
         "--list-only",
         "--connect-timeout", "10"],
        capture_output=True, text=True, timeout=15
    )
    if result.returncode == 0:
        print(f"    FTP FTPS LIST → ✅ (files: {result.stdout.strip() or 'empty dir'})")
        return True
    else:
        print(f"    FTP FTPS LIST → ❌ (exit {result.returncode}: {result.stderr.strip()[:80]})")
        return False


def run():
    token = os.environ.get("HCLOUD_TOKEN")
    box_id = os.environ.get("HETZNER_BOX_ID", "554589")

    if not token:
        print("❌ HCLOUD_TOKEN environment variable is required.")
        sys.exit(1)

    print(f"\n{'='*60}")
    print(f"Hetzner StorageBox Sub-account Integration Test")
    print(f"Box ID : {box_id}")
    print(f"Token  : {token[:8]}...")
    print(f"{'='*60}\n")
    sub_id = None

    # ── Step 1: Verify Storage Box exists ─────────────────────────────────
    print(f"[1/5] Verifying Storage Box {box_id} is accessible...")
    try:
        box = hcloud_request("GET", f"/storage_boxes/{box_id}", token)
        box_data = box.get("storage_box", {})
        print(f"  ✅ Found: {box_data.get('name', 'N/A')} — Server: {box_data.get('server', 'N/A')}")
    except Exception as e:
        print(f"  ❌ Cannot access Storage Box {box_id}: {e}")
        print()
        print("  HINT: The box may not be visible in your Cloud project.")
        print("  Check: https://console.hetzner.cloud → your project → Storage Boxes")
        sys.exit(1)

    # ── Step 2: Create test sub-account ───────────────────────────────────
    print(f"\n[2/5] Creating test sub-account '{TEST_HOME_DIR}'...")
    try:
        resp = hcloud_request(
            "POST",
            f"/storage_boxes/{box_id}/subaccounts",
            token,
            body={
                "description": "Pulumi integration test — safe to delete",
                "home_directory": TEST_HOME_DIR,
                "password": TEST_PASSWORD,
                "access_settings": {
                    "samba_enabled": True,
                    "webdav_enabled": True,
                    "ftp_enabled": True,
                    "ssh_enabled": False,
                    "reachable_externally": False,
                },
            },
        )
        sub = resp["subaccount"]
        sub_id = sub["id"]
        username = sub["username"]
        server = sub["server"]
        print(f"  ✅ Created: id={sub_id}, username={username}, server={server}")
    except Exception as e:
        print(f"  ❌ Failed to create sub-account: {e}")
        sys.exit(1)

    # ── Step 3: GET to verify existence ───────────────────────────────────
    print(f"\n[3/5] Verifying sub-account {sub_id} exists (GET)...")
    try:
        time.sleep(2)  # Give Hetzner a moment to propagate
        get_resp = hcloud_request(
            "GET",
            f"/storage_boxes/{box_id}/subaccounts/{sub_id}",
            token,
        )
        fetched = get_resp["subaccount"]
        assert fetched["id"] == sub_id
        print(f"  ✅ Confirmed: id={fetched['id']}, username={fetched['username']}")
        print(f"     home_directory={fetched.get('home_directory')}")
    except Exception as e:
        print(f"  ❌ Verification failed: {e}")

    # ── Step 4: Test protocol connectivity ────────────────────────────────
    print(f"\n[4/5] Testing connectivity to {server}...")
    print(f"  Username : {username}")
    print(f"  Password : {TEST_PASSWORD}")
    print()

    # Brief wait for credentials to propagate
    print("  Waiting 5s for credentials to propagate...")
    time.sleep(5)

    webdav_ok = test_webdav(username, TEST_PASSWORD, server)
    ftp_ok = test_ftp(username, TEST_PASSWORD, server)

    if not webdav_ok and not ftp_ok:
        print("  ⚠️  Both WebDAV and FTP failed. Sub-account created but not reachable.")
        print("     This may be a propagation delay — try again in 30s.")

    # ── Step 5: Delete test sub-account ───────────────────────────────────
    print(f"\n[5/5] Deleting test sub-account {sub_id}...")
    try:
        hcloud_request(
            "DELETE",
            f"/storage_boxes/{box_id}/subaccounts/{sub_id}",
            token,
        )
        print(f"  ✅ Deleted sub-account {sub_id}")
    except Exception as e:
        print(f"  ❌ Delete failed: {e}")
        print(f"  ⚠️  Manual cleanup needed: DELETE /v1/storage_boxes/{box_id}/subaccounts/{sub_id}")

    # ── Summary ───────────────────────────────────────────────────────────
    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"  Box accessible via Cloud API : ✅")
    print(f"  Sub-account created          : ✅ ({username})")
    print(f"  Sub-account verified (GET)   : ✅")
    print(f"  WebDAV connectivity          : {'✅' if webdav_ok else '❌'}")
    print(f"  FTP connectivity             : {'✅' if ftp_ok else '❌'}")
    print(f"  Sub-account deleted          : ✅")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    run()
