import pytest
from kubernetes import client, config
from kubernetes.client.rest import ApiException


def get_k8s_client():
    try:
        config.load_kube_config()
        return client.ApiextensionsV1Api()
    except Exception as e:
        pytest.skip(f"Kubernetes cluster not accessible: {e}")


def test_cnpg_crds_readiness():
    """
    Pre-flight check to ensure CloudNativePG CRDs are fully established
    and correctly labeled for Helm management before deploying k8s-apps.
    This prevents Server-Side Apply conflicts.
    """
    api = get_k8s_client()
    crd_names = [
        "backups.postgresql.cnpg.io",
        "clusters.postgresql.cnpg.io",
        "imagecatalogs.postgresql.cnpg.io",
        "poolers.postgresql.cnpg.io",
        "scheduledbackups.postgresql.cnpg.io",
    ]

    missing_crds = []
    invalid_labels = []

    for crd_name in crd_names:
        try:
            crd = api.read_custom_resource_definition(crd_name)

            # Check established condition
            is_established = False
            for condition in crd.status.conditions or []:
                if condition.type == "Established" and condition.status == "True":
                    is_established = True
                    break

            if not is_established:
                missing_crds.append(f"{crd_name} (Not Established)")

            # Check Helm ownership labels (required to avoid conflicts when importing)
            labels = crd.metadata.labels or {}
            if labels.get("app.kubernetes.io/managed-by") != "Helm":
                invalid_labels.append(f"{crd_name} (Missing Helm label)")

        except ApiException as e:
            if e.status == 404:
                missing_crds.append(f"{crd_name} (Not Found)")
            else:
                pytest.fail(f"API Error checking CRD {crd_name}: {e}")

    errors = []
    if missing_crds:
        errors.append(
            "Missing or Unestablished CRDs:\\n  - " + "\\n  - ".join(missing_crds)
        )
    if invalid_labels:
        errors.append(
            "CRDs missing Helm labels (will cause Server-Side conflicts):\\n  - "
            + "\\n  - ".join(invalid_labels)
        )

    if errors:
        pytest.fail("\\n\\n".join(errors))


def test_core_platform_crds_readiness():
    """
    Pre-flight check to ensure cert-manager and external-secrets CRDs
    are fully established. This prevents webhook conversion failures
    and missing kind errors during dependent app deployments.
    """
    api = get_k8s_client()
    crd_names = [
        "certificates.cert-manager.io",
        "issuers.cert-manager.io",
        "clusterissuers.cert-manager.io",
        "externalsecrets.external-secrets.io",
        "clustersecretstores.external-secrets.io",
        "secretstores.external-secrets.io",
    ]

    missing_crds = []

    for crd_name in crd_names:
        try:
            crd = api.read_custom_resource_definition(crd_name)
            is_established = False
            for condition in crd.status.conditions or []:
                if condition.type == "Established" and condition.status == "True":
                    is_established = True
                    break

            if not is_established:
                missing_crds.append(f"{crd_name} (Not Established)")

        except ApiException as e:
            if e.status == 404:
                missing_crds.append(f"{crd_name} (Not Found)")
            else:
                pytest.fail(f"API Error checking CRD {crd_name}: {e}")

    if missing_crds:
        pytest.fail(
            "Missing or Unestablished Core CRDs:\\n  - " + "\\n  - ".join(missing_crds)
        )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
