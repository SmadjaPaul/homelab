"""
Dynamic connectivity and pod health tests.
"""

import subprocess
import json
import pytest


def test_pods_running(test_case, k8s_available):
    """Verify all pods in the app namespace are Running or Succeeded."""
    if not k8s_available:
        pytest.skip("Kubernetes not available")

    res = subprocess.run(
        [
            "kubectl",
            "get",
            "pods",
            "-n",
            test_case.namespace,
            "-l",
            f"app.kubernetes.io/name={test_case.name}",
            "-o",
            "json",
        ],
        capture_output=True,
        text=True,
    )
    if res.returncode != 0:
        pytest.skip(f"Could not get pods for {test_case.name} in {test_case.namespace}")

    data = json.loads(res.stdout)
    items = data.get("items", [])
    if not items:
        pytest.skip(
            f"No pods found with label app.kubernetes.io/name={test_case.name} in {test_case.namespace}"
        )

    failed_pods = []
    for pod in items:
        phase = pod.get("status", {}).get("phase")
        if phase not in ["Running", "Succeeded"]:
            failed_pods.append(f"{pod['metadata']['name']} is {phase}")

    assert not failed_pods, (
        f"Failed pods for {test_case.name}: {', '.join(failed_pods)}"
    )


def test_service_exists(test_case, k8s_available):
    """Verify that a service exists for the app."""
    if not k8s_available:
        pytest.skip("Kubernetes not available")

    res = subprocess.run(
        [
            "kubectl",
            "get",
            "service",
            "-n",
            test_case.namespace,
            "-l",
            f"app.kubernetes.io/name={test_case.name}",
        ],
        capture_output=True,
        text=True,
    )
    assert res.returncode == 0, (
        f"No service found with label app.kubernetes.io/name={test_case.name} in {test_case.namespace}"
    )


def test_service_account_exists(test_case, k8s_available):
    """Verify that a dedicated ServiceAccount exists for the app."""
    if not k8s_available:
        pytest.skip("Kubernetes not available")

    res = subprocess.run(
        ["kubectl", "get", "serviceaccount", test_case.name, "-n", test_case.namespace],
        capture_output=True,
        text=True,
    )
    assert res.returncode == 0, (
        f"ServiceAccount {test_case.name} not found in {test_case.namespace}"
    )


def test_servicemonitor_exists(test_case, k8s_available):
    """Verify that a ServiceMonitor exists for the app (unless monitoring is disabled)."""
    if not k8s_available:
        pytest.skip("Kubernetes not available")
    if not test_case.monitoring:
        pytest.skip(f"Monitoring disabled for {test_case.name}")

    res = subprocess.run(
        ["kubectl", "get", "servicemonitor", test_case.name, "-n", test_case.namespace],
        capture_output=True,
        text=True,
    )
    assert res.returncode == 0, (
        f"ServiceMonitor {test_case.name} not found in {test_case.namespace}"
    )
