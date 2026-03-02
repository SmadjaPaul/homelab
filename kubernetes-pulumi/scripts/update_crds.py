#!/usr/bin/env python3
"""
CRD Update Script

Downloads the latest CRDs (Custom Resource Definitions) from official sources:
- cert-manager
- external-secrets
- envoy-gateway
- cloudnative-pg (CNPG)

Usage:
    python scripts/update_crds.py              # Download all CRDs
    python scripts/update_crds.py --check      # Check for updates only
    python scripts/update_crds.py --force       # Force update even if unchanged
    python scripts/update_crds.py --component cert-manager  # Update specific component
"""
import argparse
import hashlib
import os
import urllib.request
import yaml
from pathlib import Path
from datetime import datetime

# Configuration
CRD_DIR = Path(__file__).parent.parent / "k8s-core" / "crds"
VERSIONS_FILE = CRD_DIR / "versions.yaml"

# CRD sources: (url_template, filename, extract_key)
# The URL should point to the raw YAML file containing CRDs
CRD_SOURCES = {
    "cert-manager": {
        "url": "https://github.com/cert-manager/cert-manager/releases/download/{version}/cert-manager.crds.yaml",
        "version": "v1.16.2",
        "filename": "cert-manager.yaml",
    },
    "external-secrets": {
        "url": "https://github.com/external-secrets/external-secrets/releases/download/{version}/external-secrets.yaml",
        "version": "0.10.4",
        "filename": "external-secrets.yaml",
    },
    "envoy-gateway": {
        "url": "https://github.com/envoyproxy/gateway/releases/download/{version}/install.yaml",
        "version": "v1.2.1",
        "filename": "envoy-gateway.yaml",
    },
    "cnpg": {
        "url": "https://github.com/cloudnative-pg/cloudnative-pg/releases/download/{version}/crds.yaml",
        "version": "0.22.1",
        "filename": "cnpg.yaml",
    },
}


def load_versions():
    """Load current versions from versions.yaml."""
    if not VERSIONS_FILE.exists():
        return {}
    
    with open(VERSIONS_FILE) as f:
        return yaml.safe_load(f) or {}


def save_versions(versions):
    """Save versions to versions.yaml."""
    with open(VERSIONS_FILE, "w") as f:
        yaml.dump(versions, f, default_flow_style=False)


def download_crd(name: str, info: dict, force: bool = False):
    """Download a CRD file from its source."""
    url = info["url"].format(version=info["version"])
    filename = info["filename"]
    filepath = CRD_DIR / filename
    
    print(f"\n{name}:")
    print(f"  Version: {info['version']}")
    print(f"  URL: {url}")
    
    # Check if we should download
    if filepath.exists() and not force:
        # Calculate hash of current file
        with open(filepath, "rb") as f:
            current_hash = hashlib.sha256(f.read()).hexdigest()
        
        # Download to temp and compare
        temp_path = filepath.with_suffix(".tmp")
        try:
            urllib.request.urlretrieve(url, temp_path)
            with open(temp_path, "rb") as f:
                new_hash = hashlib.sha256(f.read()).hexdigest()
            
            if current_hash == new_hash:
                print(f"  Status: Up to date (unchanged)")
                os.remove(temp_path)
                return False
            else:
                print(f"  Status: Update available")
                os.replace(temp_path, filepath)
                return True
        except Exception as e:
            print(f"  Error downloading: {e}")
            if temp_path.exists():
                os.remove(temp_path)
            return False
    else:
        # Download fresh
        try:
            urllib.request.urlretrieve(url, filepath)
            print(f"  Status: Downloaded")
            return True
        except Exception as e:
            print(f"  Error downloading: {e}")
            return False


def check_updates():
    """Check for available updates without downloading."""
    current_versions = load_versions()
    
    print("Checking for CRD updates...")
    print("=" * 60)
    
    updates_available = []
    
    for name, info in CRD_SOURCES.items():
        current_version = current_versions.get(name, {}).get("version", "unknown")
        new_version = info["version"]
        
        if current_version != new_version:
            updates_available.append({
                "name": name,
                "current": current_version,
                "new": new_version,
            })
            print(f"  {name}: {current_version} -> {new_version} [UPDATE AVAILABLE]")
        else:
            print(f"  {name}: {current_version} [UP TO DATE]")
    
    if updates_available:
        print("\nUpdates available! Run with --force to update.")
    else:
        print("\nAll CRDs are up to date.")
    
    return updates_available


def cmd_update(args):
    """Download/update CRDs."""
    # Ensure CRD directory exists
    CRD_DIR.mkdir(parents=True, exist_ok=True)
    
    # Load current versions
    current_versions = load_versions()
    
    if args.check:
        return 0 if not check_updates() else 1
    
    # Determine which components to update
    components = args.component or list(CRD_SOURCES.keys())
    if isinstance(components, str):
        components = [components]
    
    updated = []
    errors = []
    
    for name in components:
        if name not in CRD_SOURCES:
            print(f"Unknown component: {name}")
            errors.append(name)
            continue
        
        info = CRD_SOURCES[name]
        try:
            if download_crd(name, info, force=args.force):
                updated.append(name)
                # Update version in current_versions
                current_versions[name] = {
                    "version": info["version"],
                    "updated": datetime.now().isoformat(),
                }
        except Exception as e:
            print(f"  Error: {e}")
            errors.append(name)
    
    # Save updated versions
    save_versions(current_versions)
    
    print("\n" + "=" * 60)
    print("Summary:")
    print(f"  Updated: {', '.join(updated) if updated else 'None'}")
    print(f"  Errors: {', '.join(errors) if errors else 'None'}")
    
    return 0 if not errors else 1


def main():
    parser = argparse.ArgumentParser(
        description="Update Kubernetes CRDs from official sources"
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Check for updates without downloading"
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Force update even if unchanged"
    )
    parser.add_argument(
        "--component",
        nargs="+",
        help="Specific component(s) to update"
    )
    
    args = parser.parse_args()
    return cmd_update(args)


if __name__ == "__main__":
    import sys
    sys.exit(main())
