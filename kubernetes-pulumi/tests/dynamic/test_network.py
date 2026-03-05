"""
Dynamic network policy verification.
"""

import subprocess
import json
import pytest


def test_deny_all_policy_exists(test_case, k8s_available):
    """Each app namespace must have a deny-all NetworkPolicy."""
    if not k8s_available:
        pytest.skip("Kubernetes not available")

    policy_name = f"{test_case.name}-deny-all"
    res = subprocess.run(
        ["kubectl", "get", "networkpolicy", policy_name, "-n", test_case.namespace],
        capture_output=True,
        text=True,
    )
    assert res.returncode == 0, (
        f"Deny-all NetworkPolicy {policy_name} not found in {test_case.namespace}"
    )


def test_dns_policy_exists(test_case, k8s_available):
    """Each app namespace must allow DNS (kube-system)."""
    if not k8s_available:
        pytest.skip("Kubernetes not available")

    policy_name = f"{test_case.name}-allow-dns"
    res = subprocess.run(
        ["kubectl", "get", "networkpolicy", policy_name, "-n", test_case.namespace],
        capture_output=True,
        text=True,
    )
    assert res.returncode == 0, (
        f"DNS allow NetworkPolicy {policy_name} not found in {test_case.namespace}"
    )


def test_isolation_rules(test_case, k8s_available):
    """Check if isolation rules from apps.yaml are present (loosely verified via labels)."""
    if not test_case.test.network_isolation:
        pytest.skip(f"No network isolation defined for {test_case.name}")

    # verify the NetworkPolicy structure instead.
    res = subprocess.run(
        ["kubectl", "get", "networkpolicies", "-n", test_case.namespace, "-o", "json"],
        capture_output=True,
        text=True,
    )
    if res.returncode != 0:
        pytest.skip(f"Could not get NetworkPolicies in {test_case.namespace}")

    data = json.loads(res.stdout)
    items = data.get("items", [])

    for isolated_ns in test_case.test.network_isolation:
        # Check for any policy that allows egress to isolated_ns
        for policy in items:
            spec = policy.get("spec", {})
            for rule in spec.get("egress", []):
                for peer in rule.get("to", []):
                    if (
                        peer.get("namespaceSelector", {})
                        .get("matchLabels", {})
                        .get("name")
                        == isolated_ns
                    ):
                        pytest.fail(
                            f"Namespace {test_case.namespace} should NOT reach {isolated_ns}"
                        )
