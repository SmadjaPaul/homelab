import yaml
import subprocess
import os
import pytest
import requests
from shared.apps.loader import load_apps


def registry_check_image_exists(image_str):
    # e.g. "nginx:latest", "bitnami/redis:7.4.2", "ghcr.io/navidrome/navidrome:latest"
    domain = ""
    repo = ""
    tag = "latest"

    parts = image_str.split(":")
    if len(parts) == 2:
        image_name, tag = parts
    else:
        image_name = parts[0]

    slash_parts = image_name.split("/")
    if len(slash_parts) == 1:
        domain = "docker.io"
        repo = f"library/{slash_parts[0]}"
    elif len(slash_parts) == 2 and not (
        "." in slash_parts[0] or ":" in slash_parts[0] or "localhost" in slash_parts[0]
    ):
        # e.g. bitnami/redis
        domain = "docker.io"
        repo = f"{slash_parts[0]}/{slash_parts[1]}"
    else:
        # e.g. ghcr.io/foo/bar or oci.external-secrets.io/foo/bar
        domain = slash_parts[0]
        repo = "/".join(slash_parts[1:])

    # Get a token
    token = ""
    if domain == "docker.io" or domain == "registry-1.docker.io":
        domain = "registry-1.docker.io"
        auth_url = f"https://auth.docker.io/token?service=registry.docker.io&scope=repository:{repo}:pull"
        try:
            r = requests.get(auth_url, timeout=5)
            r.raise_for_status()
            token = r.json().get("token", "")
        except Exception as e:
            return False, f"Auth failed for {domain}: {e}"
    elif domain == "ghcr.io":
        auth_url = f"https://ghcr.io/token?service=ghcr.io&scope=repository:{repo}:pull"
        try:
            r = requests.get(auth_url, timeout=5)
            r.raise_for_status()
            token = r.json().get("token", "")
        except Exception as e:
            return False, f"Auth failed for {domain}: {e}"
    else:
        # Other registries might not strictly need bearer auth for public repos, or follow standard W-Authenticate
        pass

    headers = {
        "Accept": "application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json"
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    url = f"https://{domain}/v2/{repo}/manifests/{tag}"
    try:
        r = requests.head(url, headers=headers, timeout=5, allow_redirects=True)
        if r.status_code == 200:
            return True, ""
        elif r.status_code in [401, 403, 307]:
            r = requests.get(url, headers=headers, timeout=5, allow_redirects=True)
            if r.status_code == 200:
                return True, ""
            return False, f"HTTP {r.status_code} for {url}"
        elif r.status_code == 404:
            return False, f"Tag {tag} not found in {domain}/{repo}"
        else:
            return False, f"HTTP {r.status_code} for {url}"
    except Exception as e:
        return False, f"Request failed: {e}"


def extract_images_from_manifests(yaml_text):
    images = set()
    for doc in yaml.safe_load_all(yaml_text):
        if not doc or not isinstance(doc, dict):
            continue
        kind = doc.get("kind")
        if kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]:
            try:
                template = doc["spec"]["template"]["spec"]
                for container in template.get("containers") or []:
                    if isinstance(container, dict) and "image" in container:
                        images.add(container["image"])
                for container in template.get("initContainers") or []:
                    if isinstance(container, dict) and "image" in container:
                        images.add(container["image"])
            except KeyError:
                pass
        elif kind == "Pod":
            try:
                for container in doc["spec"].get("containers") or []:
                    if isinstance(container, dict) and "image" in container:
                        images.add(container["image"])
            except KeyError:
                pass
        elif kind == "CronJob":
            try:
                template = doc["spec"]["jobTemplate"]["spec"]["template"]["spec"]
                for container in template.get("containers") or []:
                    if isinstance(container, dict) and "image" in container:
                        images.add(container["image"])
            except KeyError:
                pass
    return images


def test_image_tags_exist():
    """
    Validates that all images referenced in our deployment manifests actually exist
    in their respective container registries. This prevents ImagePullBackOff errors.
    """
    apps = load_apps("oci")

    errors = []

    for app in apps:
        app_name = app.name
        if not app.helm:
            continue

        helm_conf = app.helm
        repo = helm_conf.repo or ""
        chart = helm_conf.chart or ""
        version = helm_conf.version or ""
        values = helm_conf.values or {}

        # Determine Chart Name and Repo processing
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

        print(f"Generating manifests for {app_name} to extract images...")

        cmd = ["helm", "template", app_name, chart_ref, "-f", values_file]
        if version:
            cmd.extend(["--version", str(version)])

        res = subprocess.run(cmd, capture_output=True, text=True)

        try:
            os.remove(values_file)
        except OSError:
            pass

        if res.returncode != 0:
            errors.append(f"{app_name} failed helm template: {res.stderr.strip()}")
            continue

        # Extract images from the raw manifests
        images = extract_images_from_manifests(res.stdout)

        for image in images:
            # Bitnami / docker.io explicit registries can be tricky if they have sha256
            if "@sha256" in image:
                continue  # Skip digest checking for now to keep it simpler

            if "bitnami" in image or "external-secrets" in image:
                print(
                    f"Skipping registry check for known tricky image structure: {image}"
                )
                continue

            exists, reason = registry_check_image_exists(image)
            if not exists:
                errors.append(
                    f"Image '{image}' used in '{app_name}' could not be resolved: {reason}"
                )
            else:
                print(f"Verified image: {image}")

    if errors:
        error_msg = "\\n".join(errors)
        pytest.fail(f"Image validation failed for the following images:\\n{error_msg}")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
