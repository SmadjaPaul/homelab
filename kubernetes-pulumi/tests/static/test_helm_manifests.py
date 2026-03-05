import yaml
import subprocess
import os
import pytest


def get_apps_config():
    with open("apps.yaml", "r") as f:
        return yaml.safe_load(f)


def test_expected_resources_generated():
    """
    Validates that any resources declared in app.test.expected_resources
    are actually present in the final Helm rendered manifests.
    """
    config = get_apps_config()
    apps = config.get("apps", [])

    errors = []

    for app_config in apps:
        app_name = app_config.get("name")
        test_config = app_config.get("test", {})
        expected_resources = test_config.get("expected_resources", [])

        if not expected_resources:
            continue

        if "helm" not in app_config:
            continue

        helm_conf = app_config["helm"]
        repo = helm_conf.get("repo")
        chart = helm_conf.get("chart")
        version = helm_conf.get("version")
        values = helm_conf.get("values", {})

        repo_name = f"repo-{app_name}"

        is_oci = repo.startswith("oci://")

        if not is_oci:
            subprocess.run(
                ["helm", "repo", "add", repo_name, repo, "--force-update"],
                capture_output=True,
            )
            chart_ref = f"{repo_name}/{chart}"
        else:
            chart_ref = f"{repo}/{chart}"

        values_file = f"/tmp/values-{app_name}.yaml"
        with open(values_file, "w") as f:
            yaml.dump(values, f)

        res = subprocess.run(
            [
                "helm",
                "template",
                app_name,
                chart_ref,
                "--version",
                str(version),
                "-n",
                app_config.get("namespace", "default"),
                "-f",
                values_file,
            ],
            capture_output=True,
            text=True,
        )

        try:
            os.remove(values_file)
        except OSError:
            pass

        if res.returncode != 0:
            errors.append(f"{app_name} failed helm template: {res.stderr.strip()}")
            continue

        # Parse manifests and build a set of (kind, name) tuples
        rendered_resources = set()
        for doc in yaml.safe_load_all(res.stdout):
            if not doc or not isinstance(doc, dict):
                continue
            kind = doc.get("kind")
            name = doc.get("metadata", {}).get("name")
            if kind and name:
                rendered_resources.add((kind, name))

        # Validate against expected
        for expected in expected_resources:
            e_kind = expected.get("kind")
            e_name = expected.get("name")

            # Allow wildcard matching for names
            found = False
            for r_kind, r_name in rendered_resources:
                if r_kind == e_kind:
                    if e_name.endswith("*"):
                        if r_name.startswith(e_name[:-1]):
                            found = True
                            break
                    elif r_name == e_name:
                        found = True
                        break

            if not found:
                errors.append(
                    f"App '{app_name}' missing expected resource: kind={e_kind}, name={e_name} in generated manifests."
                )
                print(f"Available resources for {app_name}:")
                for r_kind, r_name in sorted(rendered_resources):
                    print(f"  - {r_kind}: {r_name}")

    if errors:
        error_msg = "\\n".join(errors)
        pytest.fail(f"Manifest validation failed:\\n{error_msg}")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
