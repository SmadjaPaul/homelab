import pytest
from kubernetes import client, config


def test_pvc_binding(all_apps):
    """
    Verify post-deployment that all PersistentVolumeClaims in our target namespaces
    reach the `Bound` phase (preventing "Waiting for First Consumer" locks forever).
    """
    config.load_kube_config()
    v1 = client.CoreV1Api()

    namespaces = set(app.namespace for app in all_apps)
    unbound_pvcs = []

    for ns in namespaces:
        try:
            pvcs = v1.list_namespaced_persistent_volume_claim(namespace=ns)
            for pvc in pvcs.items:
                if pvc.status.phase != "Bound":
                    unbound_pvcs.append(
                        f"{ns}/{pvc.metadata.name} (Phase: {pvc.status.phase})"
                    )
        except client.exceptions.ApiException as e:
            if e.status != 404:
                pytest.fail(f"API error listing PVCs in {ns}: {e}")

    if unbound_pvcs:
        pvc_list = "\\n".join(unbound_pvcs)
        pytest.fail(
            f"Found unbound PersistentVolumeClaims (Check storageClass/provider):\\n{pvc_list}"
        )
