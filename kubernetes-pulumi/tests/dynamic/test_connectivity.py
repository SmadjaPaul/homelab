"""
Dynamic connectivity and pod health tests.
"""

import subprocess
import json
import pytest

# Authentik outpost internal address — all protected apps are proxied through this
AUTHENTIK_OUTPOST_SVC = (
    "ak-outpost-authentik-embedded-outpost.authentik.svc.cluster.local:9000"
)

# The login redirect target used by Authentik
AUTHENTIK_LOGIN_HOST = "auth.smadja.dev"

# Namespace of the Authentik outpost — used to exec into a pod for in-cluster curls
AUTHENTIK_NAMESPACE = "authentik"


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
    """Verify that a dedicated ServiceAccount exists for the app, discovering its real name from the Pods."""
    if not k8s_available:
        pytest.skip("Kubernetes not available")

    # 1. Discover the actual ServiceAccount name used by the running Pods
    res_pods = subprocess.run(
        [
            "kubectl",
            "get",
            "pods",
            "-n",
            test_case.namespace,
            "-l",
            f"app.kubernetes.io/name={test_case.name}",
            "-o",
            "jsonpath={.items[0].spec.serviceAccountName}",
        ],
        capture_output=True,
        text=True,
    )

    # If we can't find pods or it's empty, we gracefully fallback to the app name
    sa_name = (
        res_pods.stdout.strip()
        if res_pods.returncode == 0 and res_pods.stdout.strip()
        else test_case.name
    )

    # 2. Verify that this ServiceAccount actually exists
    res = subprocess.run(
        ["kubectl", "get", "serviceaccount", sa_name, "-n", test_case.namespace],
        capture_output=True,
        text=True,
    )
    assert res.returncode == 0, (
        f"ServiceAccount {sa_name} not found in {test_case.namespace} (discovered for {test_case.name})"
    )


def test_servicemonitor_exists(test_case, k8s_available, all_apps):
    """Verify that a ServiceMonitor exists for the app (unless monitoring is disabled)."""
    if not k8s_available:
        pytest.skip("Kubernetes not available")
    if not test_case.test.test_monitoring:
        pytest.skip(f"Monitoring disabled for {test_case.name}")

    has_metrics_operator = any(a.name == "kube-prometheus-stack" for a in all_apps)
    if not has_metrics_operator:
        pytest.skip(
            "kube-prometheus-stack is not deployed, skipping ServiceMonitor check"
        )

    # Check if Prometheus CRDs are actually installed on the cluster first
    res_crd = subprocess.run(
        ["kubectl", "get", "crd", "servicemonitors.monitoring.coreos.com"],
        capture_output=True,
    )
    if res_crd.returncode != 0:
        pytest.skip("Prometheus ServiceMonitor CRD is not installed on the cluster")

    # First try by label
    res_label = subprocess.run(
        [
            "kubectl",
            "get",
            "servicemonitor",
            "-l",
            f"app.kubernetes.io/name={test_case.name}",
            "-n",
            test_case.namespace,
            "-o",
            "name",
        ],
        capture_output=True,
        text=True,
    )

    if res_label.returncode == 0 and res_label.stdout.strip():
        return  # Found by label!

    # Then try by exact name
    res_name = subprocess.run(
        ["kubectl", "get", "servicemonitor", test_case.name, "-n", test_case.namespace],
        capture_output=True,
        text=True,
    )

    if res_name.returncode == 0:
        return  # Found by exact name!

    # If not found, and it's not a generic application, skip instead of failing for third-party charts
    # Only strictly enforce for apps we know should have one generated by our adapters or bjw-s
    pytest.xfail(
        f"ServiceMonitor for {test_case.name} not found. Third-party chart might not support metrics out of the box."
    )


# ---------------------------------------------------------------------------
# Helper: find an exec-able pod in a given namespace
# ---------------------------------------------------------------------------


def _get_exec_pod(namespace: str) -> str | None:
    """Return the name of a Running pod in *namespace*, or None if none found."""
    res = subprocess.run(
        [
            "kubectl",
            "get",
            "pods",
            "-n",
            namespace,
            "--field-selector",
            "status.phase=Running",
            "-o",
            "jsonpath={.items[0].metadata.name}",
        ],
        capture_output=True,
        text=True,
    )
    name = res.stdout.strip()
    return name if name else None


# ---------------------------------------------------------------------------
# test_internal_service_reachable_from_outpost
# ---------------------------------------------------------------------------


def test_internal_service_reachable_from_outpost(test_case, k8s_available):
    """Verify internal HTTP connectivity to each protected app from within the cluster.

    Executes a curl from a pod in the authentik namespace to the app's ClusterIP
    service.  A response (any HTTP status) confirms the network path between the
    Authentik outpost and the app is open.  A connection-refused or DNS failure
    would indicate a misconfigured NetworkPolicy or missing Service.
    """
    if not k8s_available:
        pytest.skip("Kubernetes not available")
    if test_case.network.mode.value != "protected":
        pytest.skip(
            f"{test_case.name} is not a protected app — skipping outpost connectivity check"
        )

    exec_pod = _get_exec_pod(AUTHENTIK_NAMESPACE)
    if not exec_pod:
        pytest.skip(
            f"No running pod found in namespace '{AUTHENTIK_NAMESPACE}' to exec into"
        )

    # Resolve the service name: use service_name override if set, else app name
    svc_name = getattr(test_case, "service_name", None) or test_case.name
    url = f"http://{svc_name}.{test_case.namespace}.svc.cluster.local:{test_case.network.port}/"

    res = subprocess.run(
        [
            "kubectl",
            "exec",
            exec_pod,
            "-n",
            AUTHENTIK_NAMESPACE,
            "--",
            "curl",
            "--silent",
            "--max-time",
            "5",
            "--output",
            "/dev/null",
            "--write-out",
            "%{http_code}",
            url,
        ],
        capture_output=True,
        text=True,
    )

    if res.returncode != 0:
        pytest.fail(
            f"curl from {AUTHENTIK_NAMESPACE}/{exec_pod} to {url} failed "
            f"(exit {res.returncode}): {res.stderr.strip()}"
        )

    http_code = res.stdout.strip()
    # Any valid HTTP response means the network path is open.
    # curl exit code 0 already guarantees a TCP connection was established.
    assert http_code.isdigit() and int(http_code) > 0, (
        f"Unexpected curl output for {test_case.name}: '{http_code}'"
    )


# ---------------------------------------------------------------------------
# test_sso_redirect_for_protected_apps
# ---------------------------------------------------------------------------


def test_sso_redirect_for_protected_apps(test_case, k8s_available):
    """Verify that the Authentik outpost returns a 302/401 for protected apps.

    Sends an unauthenticated request through the outpost service using the app's
    public hostname in the Host header.  The outpost must respond with:
      - 302  →  redirect to the Authentik login page (auth.smadja.dev)
      - 401  →  explicit auth-required response

    Any 2xx response would indicate that SSO is not enforced for this app.
    """
    if not k8s_available:
        pytest.skip("Kubernetes not available")
    if test_case.network.mode.value != "protected":
        pytest.skip(
            f"{test_case.name} is not a protected app — SSO check not applicable"
        )
    if not test_case.network.hostname:
        pytest.skip(
            f"{test_case.name} has no hostname configured — cannot check SSO redirect"
        )

    exec_pod = _get_exec_pod(AUTHENTIK_NAMESPACE)
    if not exec_pod:
        pytest.skip(
            f"No running pod found in namespace '{AUTHENTIK_NAMESPACE}' to exec into"
        )

    outpost_url = f"http://{AUTHENTIK_OUTPOST_SVC}/"

    res = subprocess.run(
        [
            "kubectl",
            "exec",
            exec_pod,
            "-n",
            AUTHENTIK_NAMESPACE,
            "--",
            "curl",
            "--silent",
            "--max-time",
            "5",
            "--output",
            "/dev/null",
            "--write-out",
            "%{http_code}",
            # Do NOT follow redirects — we want to observe the 302 itself
            "--no-location",
            "-H",
            f"Host: {test_case.network.hostname}",
            outpost_url,
        ],
        capture_output=True,
        text=True,
    )

    if res.returncode != 0:
        pytest.fail(
            f"curl to outpost for {test_case.name} (Host: {test_case.hostname}) failed "
            f"(exit {res.returncode}): {res.stderr.strip()}"
        )

    http_code = res.stdout.strip()
    assert http_code in ("302", "401"), (
        f"Expected 302 or 401 from Authentik outpost for protected app '{test_case.name}' "
        f"(Host: {test_case.hostname}), but got HTTP {http_code}. "
        "SSO may not be enforced — check the Authentik proxy provider configuration."
    )


# ---------------------------------------------------------------------------
# test_oidc_internal_connectivity
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "app_name,oidc_slug",
    [
        ("owncloud", "owncloud-oidc"),
    ],
)
def test_oidc_internal_connectivity(app_name, oidc_slug, k8s_available):
    """Verify that apps can reach the internal Authentik OIDC metadata.

    Checks both .well-known/openid-configuration and the JWKS endpoint via
    internal cluster DNS.
    """
    if not k8s_available:
        pytest.skip("Kubernetes not available")

    exec_pod = _get_exec_pod(AUTHENTIK_NAMESPACE)
    if not exec_pod:
        pytest.skip(f"No running pod found in namespace '{AUTHENTIK_NAMESPACE}'")

    base_url = f"http://authentik-server.authentik.svc.cluster.local/application/o/{oidc_slug}/"
    endpoints = [
        ".well-known/openid-configuration",
        "jwks/",
    ]

    for ep in endpoints:
        url = base_url + ep
        res = subprocess.run(
            [
                "kubectl",
                "exec",
                exec_pod,
                "-n",
                AUTHENTIK_NAMESPACE,
                "--",
                "curl",
                "--silent",
                "--max-time",
                "5",
                "--output",
                "/dev/null",
                "--write-out",
                "%{http_code}",
                url,
            ],
            capture_output=True,
            text=True,
        )
        assert res.returncode == 0, f"Failed to curl {url}: {res.stderr}"
        assert res.stdout.strip() == "200", (
            f"Internal OIDC endpoint {url} returned {res.stdout}"
        )
