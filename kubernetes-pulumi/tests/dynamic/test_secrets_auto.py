"""
Auto-discovered secrets tests.

Tests that secrets are properly synchronized for all apps.
"""

import subprocess
import json

import pytest


class TestClusterSecretStore:
    """Verify ClusterSecretStore is ready."""

    @pytest.fixture(autouse=True)
    def check_cluster(self, cluster_available):
        if not cluster_available:
            pytest.skip("Kubernetes cluster not available")

    def test_clustersecretstore_exists(self):
        """The doppler ClusterSecretStore must exist."""
        result = subprocess.run(
            ["kubectl", "get", "clustersecretstore", "doppler", "-o", "json"],
            capture_output=True,
            text=True,
            timeout=15,
        )
        assert result.returncode == 0, "ClusterSecretStore 'doppler' not found"

    def test_clustersecretstore_ready(self):
        """The doppler ClusterSecretStore must be Ready."""
        result = subprocess.run(
            ["kubectl", "get", "clustersecretstore", "doppler", "-o", "json"],
            capture_output=True,
            text=True,
            timeout=15,
        )
        if result.returncode != 0:
            pytest.skip("ClusterSecretStore not found")

        store = json.loads(result.stdout)
        conditions = store.get("status", {}).get("conditions", [])

        ready = any(
            c.get("type") == "Ready" and c.get("status") == "True" for c in conditions
        )
        assert ready, "ClusterSecretStore not Ready"


@pytest.mark.secrets
def test_external_secrets_synced(apps_with_secrets, k8s_client):
    """Test that ExternalSecrets are synced for each app."""
    if not k8s_client.is_cluster_available():
        pytest.skip("Cluster not available")

    for app in apps_with_secrets:
        if not app.secrets:
            continue

        for secret in app.secrets:
            result = subprocess.run(
                [
                    "kubectl",
                    "get",
                    "externalsecret",
                    secret.name,
                    "-n",
                    app.namespace,
                    "-o",
                    "json",
                ],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode != 0:
                pytest.fail(
                    f"ExternalSecret '{secret.name}' not found in {app.namespace}"
                )

            es = json.loads(result.stdout)
            status = es.get("status", {}).get("conditions", [])
            synced = any(
                c.get("type") == "SecretSynced" and c.get("status") == "True"
                for c in status
            )
            assert synced, f"Secret {secret.name} not synced in {app.namespace}"
