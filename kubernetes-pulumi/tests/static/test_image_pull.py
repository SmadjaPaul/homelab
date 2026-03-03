"""
Image Pull Test

Tests that container images can actually be pulled from their registries.
This prevents ImagePullBackOff errors due to:
- Docker Hub rate limiting
- Invalid image tags
- Authentication issues
"""
import subprocess
import pytest
import yaml
from typing import Tuple


def get_apps_config():
    with open("apps.yaml", "r") as f:
        return yaml.safe_load(f)


def parse_image(image_str: str) -> Tuple[str, str, str]:
    """
    Parse image string into registry, repository, and tag.
    
    Examples:
    - redis:7.2 -> (docker.io, library/redis, 7.2)
    - ghcr.io/bitnami/redis:7.4 -> (ghcr.io, bitnami/redis, 7.4)
    - nginx:latest -> (docker.io, library/nginx, latest)
    """
    # Split tag from image
    if ":" in image_str:
        image, tag = image_str.rsplit(":", 1)
    else:
        image = image_str
        tag = "latest"
    
    # Determine registry
    if "/" in image:
        first_part = image.split("/")[0]
        if "." in first_part or first_part == "ghcr.io":
            registry = first_part
            repository = "/".join(image.split("/")[1:])
        else:
            registry = "docker.io"
            repository = image
    else:
        registry = "docker.io"
        repository = f"library/{image}"
    
    return registry, repository, tag


def can_pull_image(image: str) -> Tuple[bool, str]:
    """
    Test if an image can be pulled using docker/ctr.
    Returns (success, message).
    """
    # Use crictl to test pull (works with containerd)
    cmd = ["crictl", "pull", image]
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.returncode == 0:
            return True, "Pull successful"
        else:
            return False, f"Pull failed: {result.stderr.strip()}"
    except FileNotFoundError:
        # crictl not available, try docker
        try:
            result = subprocess.run(
                ["docker", "manifest", "inspect", image],
                capture_output=True,
                text=True,
                timeout=30
            )
            if result.returncode == 0:
                return True, "Image accessible (manifest found)"
            else:
                return False, f"Docker manifest failed: {result.stderr.strip()}"
        except FileNotFoundError:
            return False, "No container runtime tools available (crictl, docker)"
    except subprocess.TimeoutExpired:
        return False, "Pull timed out"
    except Exception as e:
        return False, f"Error: {str(e)}"


def extract_images_from_helm_values(values: dict) -> set:
    """Extract all image references from helm values."""
    images = set()
    
    def recursive_find(obj, path=""):
        if isinstance(obj, dict):
            # Check for common image fields
            if "image" in obj:
                img = obj["image"]
                if isinstance(img, str):
                    images.add(img)
                elif isinstance(img, dict):
                    # Build image from repository and tag
                    repo = img.get("repository", "")
                    tag = img.get("tag", "latest")
                    if repo:
                        full_image = f"{repo}:{tag}" if ":" in tag else repo
                        images.add(full_image)
            for key, value in obj.items():
                recursive_find(value, f"{path}.{key}")
        elif isinstance(obj, list):
            for i, item in enumerate(obj):
                recursive_find(item, f"{path}[{i}]")
    
    recursive_find(values)
    return images


def test_images_can_be_pulled():
    """
    Validates that all images referenced in apps.yaml can be pulled.
    This prevents ImagePullBackOff errors in Kubernetes.
    """
    config = get_apps_config()
    apps = config.get("apps", [])
    
    results = []
    
    for app in apps:
        app_name = app.get("name", "unknown")
        
        if "helm" not in app:
            continue
        
        helm_values = app.get("helm", {}).get("values", {})
        images = extract_images_from_helm_values(helm_values)
        
        for image in images:
            can_pull, message = can_pull_image(image)
            results.append({
                "app": app_name,
                "image": image,
                "success": can_pull,
                "message": message
            })
    
    # Print results
    print("\n" + "="*60)
    print("Image Pull Test Results")
    print("="*60)
    
    failures = []
    for r in results:
        status = "✓" if r["success"] else "✗"
        print(f"{status} {r['app']}: {r['image']}")
        print(f"    {r['message']}")
        
        if not r["success"]:
            failures.append(f"{r['app']} ({r['image']}): {r['message']}")
    
    print("="*60)
    
    if failures:
        pytest.fail(
            f"Image pull failures detected:\n" + 
            "\n".join(f"  - {f}" for f in failures)
        )


def test_dockerhub_rate_limit_status():
    """
    Check Docker Hub rate limit status.
    This helps identify if we need to use alternative registries.
    """
    import requests
    
    # Docker Hub rate limit API (anonymous)
    url = "https://registry-1.docker.io/v2/"
    
    try:
        r = requests.head(url, timeout=5)
        # Check rate limit headers
        remaining = r.headers.get("ratelimit-remaining", "unknown")
        print(f"\nDocker Hub rate limit remaining: {remaining}")
        
        # If rate limit is very low, warn
        if remaining != "unknown":
            limit = int(remaining.split(";")[0].split("=")[1]) if "=" in remaining else 0
            if limit < 10:
                pytest.fail(f"Docker Hub rate limit critically low: {remaining}")
    except Exception as e:
        print(f"Could not check Docker Hub rate limit: {e}")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
