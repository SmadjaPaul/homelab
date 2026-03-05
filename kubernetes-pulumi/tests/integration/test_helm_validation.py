import pytest
import os
import yaml
import subprocess
import tempfile
from shared.apps.loader import AppLoader
from shared.apps.generic import GenericHelmApp


def test_helm_template_validation():
    """
    Validation Rule: Every app in 'apps.yaml' must survive a 'helm template'
    dry-run with its computed final values. This catches schema violations
    (e.g. additionalProperties: false) before we even hit the cluster.
    """
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    apps_yaml_path = os.path.join(project_root, "apps.yaml")

    loader = AppLoader(apps_yaml_path)
    # We validate for 'oci' cluster as it's our primary target
    apps = loader.load_for_cluster("oci")

    errors = []

    for app_model in apps:
        if not app_model.helm:
            continue

        print(f"Validating Helm template for {app_model.name}...")

        # Instantiate the generic app to get final values
        app = GenericHelmApp(app_model)
        final_values = app.get_final_values()

        # Run helm template
        with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml") as tmp:
            yaml.dump(final_values, tmp)
            tmp.flush()

            chart_name = app_model.helm.chart
            repo_url = app_model.helm.repo
            version = app_model.helm.version

            cmd = ["helm", "template", app_model.name]

            if repo_url and repo_url.startswith("oci://"):
                # OCI charts are handled differently in helm template
                # Format: helm template [NAME] oci://.../[CHART] --version [VERSION]
                cmd.append(f"{repo_url}/{chart_name}")
            else:
                cmd.append(chart_name)
                if repo_url:
                    cmd.extend(["--repo", repo_url])

            if version:
                cmd.extend(["--version", version])

            cmd.extend(["--values", tmp.name])

            # Use --include-crds to be more thorough if needed
            # cmd.append("--include-crds")

            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode != 0:
                print(f"FAILED: {app_model.name}")
                print(f"STDOUT: {result.stdout}")
                print(f"STDERR: {result.stderr}")
                errors.append(
                    f"App '{app_model.name}' failed Helm validation: {result.stderr}"
                )

    if errors:
        pytest.fail("\n".join(errors))


if __name__ == "__main__":
    test_helm_template_validation()
