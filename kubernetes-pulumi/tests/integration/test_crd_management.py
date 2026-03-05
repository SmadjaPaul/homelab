import os
from shared.apps.loader import AppLoader


def test_critical_operators_skip_crds():
    """
    Verify that critical operators have skip_crds=True set in apps.yaml.
    This is essential for our CRD-First approach where CRDs are managed
    independently with Server-Side Apply.
    """
    project_root = os.path.dirname(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    )
    apps_yaml_path = os.path.join(project_root, "apps.yaml")

    loader = AppLoader(apps_yaml_path)
    apps = loader.load_for_cluster("oci")

    # Operators that must have skip_crds=True
    critical_operators = ["external-secrets", "cert-manager"]

    apps_dict = {app.name: app for app in apps}

    for op_name in critical_operators:
        assert op_name in apps_dict, (
            f"Operator {op_name} not found in apps.yaml for oci cluster"
        )
        app = apps_dict[op_name]
        assert app.skip_crds is True, f"Operator {op_name} must have skip_crds: true"

        # Also verify that Helm values disable CRD installation as a secondary safety
        if op_name == "external-secrets":
            assert app.helm.values.get("installCRDs") is False, (
                "external-secrets helm values must set installCRDs: false"
            )
        elif op_name == "cert-manager":
            assert app.helm.values.get("crds", {}).get("enabled") is False, (
                "cert-manager helm values must set crds.enabled: false"
            )


def test_crd_dependency_ordering():
    """
    Verify that apps that depend on operators also indirectly depend on their CRDs.
    (This is a static check on the dependency graph).
    """
    project_root = os.path.dirname(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    )
    apps_yaml_path = os.path.join(project_root, "apps.yaml")

    loader = AppLoader(apps_yaml_path)
    apps = loader.load_for_cluster("oci")

    apps_dict = {app.name: app for app in apps}

    # Check cloudflared -> external-secrets
    assert "cloudflared" in apps_dict
    assert "external-secrets" in apps_dict["cloudflared"].dependencies
