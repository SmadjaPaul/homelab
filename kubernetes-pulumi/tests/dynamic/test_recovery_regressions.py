from kubernetes import client, config


def test_no_image_pull_backoff():
    """Verify no pods are stuck pulling images."""
    config.load_kube_config()
    v1 = client.CoreV1Api()
    pods = v1.list_pod_for_all_namespaces()

    failing = []
    for pod in pods.items:
        if pod.status.container_statuses:
            for cs in pod.status.container_statuses:
                if cs.state.waiting and cs.state.waiting.reason in [
                    "ImagePullBackOff",
                    "ErrImagePull",
                ]:
                    failing.append(
                        f"{pod.metadata.namespace}/{pod.metadata.name}: {cs.state.waiting.message or cs.state.waiting.reason}"
                    )

    assert not failing, f"Pods failing to pull images: {failing}"


def test_smb_mount_success():
    """Check pod events for SMB mount failures."""
    config.load_kube_config()
    v1 = client.CoreV1Api()
    events = v1.list_event_for_all_namespaces()

    mount_errors = []
    for event in events.items:
        if event.reason in ["FailedMount", "FailedAttachVolume"]:
            if "Permission denied" in event.message or "mount failed" in event.message:
                mount_errors.append(
                    f"{event.involved_object.namespace}/{event.involved_object.name}: {event.message}"
                )

    assert not mount_errors, f"SMB mount errors detected: {mount_errors}"


def test_pvc_binding_all():
    """Verify all PVCs are Bound."""
    config.load_kube_config()
    v1 = client.CoreV1Api()
    pvcs = v1.list_persistent_volume_claim_for_all_namespaces()

    unbound = []
    for pvc in pvcs.items:
        # We skip PVCs that might be in a temporary Pending state during a rollout
        # but for a stabilization test, we expect everything to be Bound eventually.
        if pvc.status.phase != "Bound":
            unbound.append(
                f"{pvc.metadata.namespace}/{pvc.metadata.name} is in phase {pvc.status.phase}"
            )

    assert not unbound, f"Unbound PVCs: {unbound}"
