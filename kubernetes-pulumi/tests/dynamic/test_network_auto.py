"""
Auto-discovered network policy tests.

Tests that network isolation is properly enforced for all apps.
"""

import subprocess

import pytest


@pytest.mark.network
def test_deny_all_policy_exists(apps_with_network_policy, k8s_client):
    """Each app namespace must have a deny-all NetworkPolicy."""
    if not k8s_client.is_cluster_available():
        pytest.skip("Cluster not available")

    for app in apps_with_network_policy:
        policy_name = f"{app.name}-deny-all"

        result = subprocess.run(
            [
                "kubectl",
                "get",
                "networkpolicy",
                policy_name,
                "-n",
                app.namespace,
                "-o",
                "json",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )

        assert result.returncode == 0, (
            f"Deny-all NetworkPolicy '{policy_name}' not found in namespace '{app.namespace}'"
        )


@pytest.mark.network
def test_dns_policy_exists(apps_with_network_policy, k8s_client):
    """Each app namespace must allow DNS (kube-system)."""
    if not k8s_client.is_cluster_available():
        pytest.skip("Cluster not available")

    for app in apps_with_network_policy:
        policy_name = f"{app.name}-allow-dns"

        result = subprocess.run(
            [
                "kubectl",
                "get",
                "networkpolicy",
                policy_name,
                "-n",
                app.namespace,
                "-o",
                "json",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )

        assert result.returncode == 0, (
            f"DNS allow NetworkPolicy '{policy_name}' not found in namespace '{app.namespace}'"
        )


@pytest.mark.network
def test_dependency_policies_exist(apps_with_network_policy, k8s_client):
    """Each app must allow egress to its declared dependencies."""
    if not k8s_client.is_cluster_available():
        pytest.skip("Cluster not available")

    for app in apps_with_network_policy:
        for dep in app.dependencies:
            policy_name = f"{app.name}-allow-{dep}"

            result = subprocess.run(
                [
                    "kubectl",
                    "get",
                    "networkpolicy",
                    policy_name,
                    "-n",
                    app.namespace,
                    "-o",
                    "json",
                ],
                capture_output=True,
                text=True,
                timeout=10,
            )

            assert result.returncode == 0, (
                f"Dependency policy '{policy_name}' not found in namespace '{app.namespace}'"
            )
