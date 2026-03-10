import pytest
from kubernetes import client, config


def test_app_startup_health(all_apps):
    """
    Probe running Pods to ensure none are stuck in `CreateContainerConfigError`,
    `CrashLoopBackOff`, or `ImagePullBackOff`. They should ideally be 'Running' or 'Succeeded'.
    """
    config.load_kube_config()
    v1 = client.CoreV1Api()

    namespaces = set(app.namespace for app in all_apps)
    failing_pods = []

    # Tolerable phases/reasons if they are just slowly starting,
    # but we strictly disallow obvious configuration failures.
    fatal_reasons = [
        "CreateContainerConfigError",
        "CreateContainerError",
        "ImagePullBackOff",
        "ErrImagePull",
        "CrashLoopBackOff",
    ]

    for ns in namespaces:
        try:
            pods = v1.list_namespaced_pod(namespace=ns)
            for pod in pods.items:
                # 1. Check overall phase
                if pod.status.phase in ["Failed", "Unknown"]:
                    failing_pods.append(
                        f"{ns}/{pod.metadata.name} is in phase {pod.status.phase}"
                    )
                    continue

                # 2. Check container statuses
                if pod.status.container_statuses:
                    for container in pod.status.container_statuses:
                        state = container.state
                        if state.waiting and state.waiting.reason in fatal_reasons:
                            failing_pods.append(
                                f"{ns}/{pod.metadata.name} (Container {container.name}) "
                                f"stuck in {state.waiting.reason}: {state.waiting.message}"
                            )
                        elif (
                            state.terminated
                            and state.terminated.exit_code != 0
                            and state.terminated.reason != "Completed"
                        ):
                            # Allow completed jobs, flag crashed containers
                            failing_pods.append(
                                f"{ns}/{pod.metadata.name} (Container {container.name}) "
                                f"terminated with code {state.terminated.exit_code} ({state.terminated.reason})"
                            )
        except client.exceptions.ApiException as e:
            if e.status != 404:
                pytest.fail(f"API error listing Pods in {ns}: {e}")

    if failing_pods:
        pod_list = "\\n".join(failing_pods)
        pytest.fail(f"Found Pods with startup/configuration errors:\\n{pod_list}")
