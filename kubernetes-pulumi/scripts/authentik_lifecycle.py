#!/usr/bin/env python3
"""
Authentik lifecycle helpers for stack_manager.py.

Automates the 3 manual steps previously required around `pulumi up`:
1. Port-forward to authentik-server (pre-deploy)
2. Outpost reconciliation (post-deploy)
3. Service selector fix (post-deploy)
"""

import subprocess
import time
import urllib.request
import urllib.error


AUTHENTIK_NS = "authentik"
AUTHENTIK_SVC = "authentik-server"
LOCAL_PORT = 9000
HEALTH_URL = f"http://localhost:{LOCAL_PORT}/api/v3/root/config/"
POLL_INTERVAL = 2
POLL_TIMEOUT = 60


def start_port_forward() -> subprocess.Popen | None:
    """Start a port-forward to authentik-server if needed. Returns Popen or None."""
    # Check if port is already serving authentik
    if _is_authentik_reachable():
        print("[lifecycle] Authentik already reachable on localhost:9000")
        return None

    # Check if an authentik-server pod is running
    try:
        result = subprocess.run(
            [
                "kubectl",
                "get",
                "pods",
                "-n",
                AUTHENTIK_NS,
                "-l",
                "app.kubernetes.io/name=authentik,app.kubernetes.io/component=server",
                "--field-selector=status.phase=Running",
                "-o",
                "name",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if not result.stdout.strip():
            print("[lifecycle] No running authentik-server pod found (first deploy?)")
            return None
    except Exception as e:
        print(f"[lifecycle] Could not check for authentik pods: {e}")
        return None

    # Start port-forward
    print(f"[lifecycle] Starting port-forward to {AUTHENTIK_SVC}:{LOCAL_PORT}...")
    proc = subprocess.Popen(
        [
            "kubectl",
            "port-forward",
            f"svc/{AUTHENTIK_SVC}",
            f"{LOCAL_PORT}:80",
            "-n",
            AUTHENTIK_NS,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    # Poll until healthy
    deadline = time.monotonic() + POLL_TIMEOUT
    while time.monotonic() < deadline:
        time.sleep(POLL_INTERVAL)
        if proc.poll() is not None:
            print("[lifecycle] Port-forward process exited unexpectedly")
            return None
        if _is_authentik_reachable():
            print("[lifecycle] Authentik reachable via port-forward")
            return proc

    print("[lifecycle] Timed out waiting for authentik to respond")
    proc.terminate()
    return None


def stop_port_forward(proc: subprocess.Popen | None):
    """Terminate the port-forward process if we started one."""
    if proc is None:
        return
    print("[lifecycle] Stopping port-forward...")
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()


def post_deploy_reconcile() -> bool:
    """Run outpost reconciliation via the authentik worker pod."""
    print("[lifecycle] Running post-deploy outpost reconciliation...")

    # Find worker pod
    try:
        result = subprocess.run(
            [
                "kubectl",
                "get",
                "pod",
                "-n",
                AUTHENTIK_NS,
                "-l",
                "app.kubernetes.io/component=worker",
                "-o",
                "name",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        pods = result.stdout.strip().splitlines()
        if not pods:
            print(
                "[lifecycle] Warning: No authentik worker pod found, skipping reconciliation"
            )
            return False
        worker_pod = pods[0]
    except Exception as e:
        print(f"[lifecycle] Could not find worker pod: {e}")
        return False

    # Run Django reconciliation script
    reconcile_script = """
import django, os
os.environ['DJANGO_SETTINGS_MODULE'] = 'authentik.root.settings'
django.setup()
from authentik.outposts.models import Outpost
from authentik.providers.proxy.controllers.kubernetes import ProxyKubernetesController
for outpost in Outpost.objects.filter(type='proxy'):
    if not outpost.service_connection:
        print(f'Skipping outpost {outpost.name}: no service connection linked yet')
        continue
    try:
        ctrl = ProxyKubernetesController(outpost, outpost.service_connection)
        list(ctrl.up_with_logs())
        print(f'Reconciled outpost: {outpost.name}')
    except Exception as e:
        print(f'Failed to reconcile {outpost.name}: {e}')
print('Done')
"""

    try:
        result = subprocess.run(
            [
                "kubectl",
                "exec",
                "-n",
                AUTHENTIK_NS,
                worker_pod,
                "--",
                "python",
                "-c",
                reconcile_script,
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )
        print(result.stdout)
        if result.returncode != 0:
            print(f"[lifecycle] Reconciliation failed: {result.stderr}")
            return False
        print("[lifecycle] Outpost reconciliation complete")
        return True
    except Exception as e:
        print(f"[lifecycle] Reconciliation error: {e}")
        return False


def _is_authentik_reachable() -> bool:
    """Check if authentik API is responding on localhost."""
    try:
        req = urllib.request.Request(HEALTH_URL, method="GET")
        with urllib.request.urlopen(req, timeout=3) as resp:
            return resp.status == 200
    except Exception:
        return False
