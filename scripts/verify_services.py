import yaml
import requests
import sys
from pathlib import Path


def main():
    project_root = Path(__file__).parent.parent
    config_path = project_root / "kubernetes-pulumi" / "apps.yaml"

    if not config_path.exists():
        print(f"Error: Config not found at {config_path}")
        sys.exit(1)

    with open(config_path) as f:
        config = yaml.safe_load(f)

    apps = config.get("apps", [])
    domain = config.get("domain", "smadja.dev")

    results = []
    print(f"--- Verifying Services for {domain} ---")

    for app in apps:
        name = app.get("name")
        hostname = app.get("hostname")
        mode = app.get("mode", "internal")

        if mode == "internal" or not hostname:
            continue

        url = f"https://{hostname}"
        try:
            # We allow 401/302 as "healthy" for protected apps as they redirect to Authentik
            response = requests.get(url, timeout=10, verify=False)
            status = response.status_code

            # 200: OK
            # 302: Redirect (likely to Authentik)
            # 401: Unauthorized (if handled by app)
            # 500/502/503/504: Error

            is_healthy = status in [200, 301, 302, 401]
            icon = "✅" if is_healthy else "❌"

            print(f"{icon} {name:20} | {url:30} | Status: {status}")
            results.append((name, is_healthy, status))

        except Exception as e:
            print(f"❌ {name:20} | {url:30} | Error: {str(e)}")
            results.append((name, False, str(e)))

    print("\n--- Summary ---")
    failed = [name for name, healthy, _ in results if not healthy]
    if failed:
        print(f"Failed services: {', '.join(failed)}")
        sys.exit(1)
    else:
        print("All external services are reachable!")


if __name__ == "__main__":
    main()
