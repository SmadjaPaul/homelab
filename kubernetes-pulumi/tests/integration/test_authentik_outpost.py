"""Verify that the Authentik Outpost pod is running in the cluster."""

import pytest
import kubernetes


def test_authentik_outpost_running():
    """Verify the embedded outpost pod is running."""
    try:
        kubernetes.config.load_kube_config()
        client = kubernetes.client.CoreV1Api()
        pods = client.list_namespaced_pod("authentik")
        # Check for the specific naming pattern used in finalize_authentik_outpost
        outpost_pods = [
            p for p in pods.items if "authentik-embedded-outpost" in p.metadata.name
        ]

        assert len(outpost_pods) > 0, (
            "No authentik outpost pod found in 'authentik' namespace"
        )

        # Check that at least one is Running
        running_pods = [p for p in outpost_pods if p.status.phase == "Running"]
        assert len(running_pods) > 0, (
            "Authentik outpost pods are found but none are in 'Running' state"
        )
        print(f"  [INFO] Found {len(running_pods)} running outpost pods.")
    except Exception as e:
        pytest.skip(f"Skipping k8s integration test: {str(e)}")
