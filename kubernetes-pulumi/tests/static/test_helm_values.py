import yaml
import subprocess
import os
import pytest
from conftest import get_apps_config


def test_helm_values_schema():
    """
    Extracts all Helm values from apps.yaml and validates them against their
    respective Helm charts using `helm template`. This instantly catches schema
    violations (like the Navidrome app-template v3 issue) before Pulumi runs.
    """
    config = get_apps_config()
    apps = config.get("apps", [])

    errors = []

    for app_config in apps:
        app_name = app_config.get("name")
        if app_name == "romm":
            continue
        if "helm" not in app_config:
            continue

        helm_conf = app_config["helm"]
        repo = helm_conf.get("repo", "")
        chart = helm_conf.get("chart", "")
        version = helm_conf.get("version", "")
        values = helm_conf.get("values", {})

        # Determine Chart Name and Repo processing
        # GenericHelmApp handles OCI URLs and defaults
        if not repo:
            if app_name == "redis":
                repo = "https://charts.bitnami.com/bitnami"
            else:
                continue

        if repo.startswith("oci://"):
            chart_ref = f"{repo.rstrip('/')}/{chart}"
            repo_name = ""
        else:
            repo_name = f"repo-{app_name}"
            subprocess.run(
                ["helm", "repo", "add", repo_name, repo, "--force-update"],
                capture_output=True,
            )
            subprocess.run(["helm", "repo", "update", repo_name], capture_output=True)
            chart_ref = f"{repo_name}/{chart}"

        values_file = f"/tmp/values-{app_name}.yaml"
        with open(values_file, "w") as f:
            yaml.dump(values, f)

        print(f"Validating helm schema for {app_name} ({chart_ref} v{version})...")

        # Run helm template to force schema validation
        cmd = ["helm", "template", app_name, chart_ref, "-f", values_file]
        if version:
            cmd.extend(["--version", str(version)])

        res = subprocess.run(cmd, capture_output=True, text=True)

        if res.returncode != 0:
            errors.append(f"{app_name}: {res.stderr.strip()}")

        # Clean up
        try:
            os.remove(values_file)
        except Exception:
            pass

    if errors:
        error_msg = "\\n".join(errors)
        pytest.fail(
            f"Helm schema validation failed for the following apps:\\n{error_msg}"
        )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
