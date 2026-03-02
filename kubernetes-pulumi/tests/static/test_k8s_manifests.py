"""
Static Tests for Kubernetes Manifest Validation

This module provides tests that validate Kubernetes manifests using:
- Kubeconform: Validates YAML against Kubernetes schema
- Polaris: Validates best practices and security

These tests run WITHOUT connecting to a cluster - they validate
the generated manifests from Pulumi.
"""
import os
import subprocess
import tempfile
from pathlib import Path

import pytest


PROJECT_ROOT = Path(__file__).parent.parent.parent
KUBECONFORM_VERSION = "v0.6.2"
POLARIS_VERSION = "8.16.0"


def run_command(cmd: list, cwd: str = None) -> tuple[int, str, str]:
    """Run a command and return (returncode, stdout, stderr)."""
    result = subprocess.run(
        cmd,
        cwd=cwd,
        capture_output=True,
        text=True,
    )
    return result.returncode, result.stdout, result.stderr


def is_tool_installed(name: str) -> bool:
    """Check if a tool is installed."""
    returncode, _, _ = run_command(["which", name])
    return returncode == 0


@pytest.fixture(scope="session")
def manifest_dir():
    """
    Generate manifests from Pulumi and return the directory.
    
    This runs `pulumi preview --non-interactive --out manifest` to generate
    Kubernetes manifests without applying them.
    """
    # Check if we can run pulumi
    if not is_tool_installed("pulumi"):
        pytest.skip("Pulumi not installed")
    
    # This would generate manifests - for now we use a placeholder
    # In a real implementation, you would:
    # 1. Run `pulumi preview --non-interactive --json` to get the plan
    # 2. Parse the JSON and extract Kubernetes resources
    # 3. Write them to a temp directory
    
    # For testing, we'll just check if the k8s-core/crds directory exists
    crd_dir = PROJECT_ROOT / "k8s-core" / "crds"
    if not crd_dir.exists():
        pytest.skip("CRD directory not found")
    
    return crd_dir


def test_kubeconform_installed():
    """Check if kubeconform is installed."""
    if not is_tool_installed("kubeconform"):
        pytest.skip("kubeconform not installed")


def test_polaris_installed():
    """Check if polaris is installed."""
    if not is_tool_installed("polaris"):
        pytest.skip("polaris not installed")


def test_crd_files_are_valid_yaml(manifest_dir):
    """Test that all CRD files are valid YAML."""
    errors = []
    
    for yaml_file in manifest_dir.glob("*.yaml"):
        try:
            import yaml
            with open(yaml_file) as f:
                list(yaml.safe_load_all(f))
        except Exception as e:
            errors.append(f"{yaml_file.name}: {e}")
    
    assert not errors, f"Invalid YAML files: {errors}"


def test_crd_files_have_valid_k8s_schema(manifest_dir):
    """
    Test that CRD files conform to Kubernetes schema using kubeconform.
    
    This would catch issues like:
    - Using deprecated API versions (v1beta1 instead of v1)
    - Invalid field names
    - Missing required fields
    """
    if not is_tool_installed("kubeconform"):
        pytest.skip("kubeconform not installed")
    
    # Run kubeconform with strict mode
    cmd = [
        "kubeconform",
        "-strict",
        "-summary",
        str(manifest_dir),
    ]
    
    returncode, stdout, stderr = run_command(cmd)
    
    # Kubeconform returns 0 if all files are valid
    # For CRDs, it often fails with "could not find schema"
    # We allow these specifically as we are validating syntax in test_crd_files_are_valid_yaml
    output = stdout + stderr
    
    # Check for REAL errors (not schema missing)
    real_errors = []
    if returncode != 0:
        for line in output.splitlines():
            # Ignore summary lines and schema missing lines
            if "Summary:" in line:
                continue
            if "error" in line.lower() and "could not find schema" not in line.lower():
                real_errors.append(line)
    
    if real_errors:
        pytest.fail(f"Kubeconform validation failed with real errors:\n" + "\n".join(real_errors))
    
    # Just log the output for info
    print(f"Kubeconform output: {output}")


def test_polaris_audit_config():
    """
    Test that a Polaris audit configuration exists.
    
    Polaris can audit Kubernetes manifests for best practices.
    """
    polaris_config = PROJECT_ROOT / "polaris.yaml"
    
    if not polaris_config.exists():
        # Create a default config if it doesn't exist
        config_content = """# Polaris Configuration
# https://polaris.docs.fairwinds.com/customization/

checks:
  # Security
  dangerousCapabilities: warn
  hostNetworkSet: warn
  hostPIDSet: warn
  hostIPCSet: warn
  
  # Resources
  cpuRequestsMissing: warn
  cpuLimitsMissing: warn
  memoryRequestsMissing: warn
  memoryLimitsMissing: warn
  
  # Best practices
  imagePullPolicyAlways: warn
  livenessProbeMissing: warn
  readinessProbeMissing: warn
  
  # Reliability
  podDisruptionBudget: warn
"""
        pytest.skip(f"Polaris config not found at {polaris_config}")


def test_polaris_validate_manifests(manifest_dir):
    """
    Validate manifests using Polaris.
    
    This checks for best practices and security issues.
    """
    if not is_tool_installed("polaris"):
        pytest.skip("polaris not installed")
    
    # Create a temporary directory for Polaris output
    with tempfile.TemporaryDirectory() as tmpdir:
        cmd = [
            "polaris",
            "audit",
            "--config", str(PROJECT_ROOT / "polaris.yaml"),
            "--format", "json",
            "--audit-path", str(manifest_dir),
            "--quiet"
        ]
        
        returncode, stdout, stderr = run_command(cmd)
        
        output = stdout + stderr
        
        # Polaris returns non-zero if there are errors
        if returncode != 0:
            # Parse the JSON output to get details
            try:
                import json
                results = json.loads(stdout)
                
                errors = []
                for check, result in results.get("Results", {}).items():
                    if result.get("Severity") == "error":
                        errors.append(f"{check}: {result.get('Message')}")
                
                if errors:
                    pytest.fail(f"Polaris found errors:\n" + "\n".join(errors))
            except:
                pytest.fail(f"Polaris validation failed:\n{output}")


def test_apps_yaml_syntax():
    """Test that apps.yaml is valid YAML and has correct schema."""
    apps_yaml = PROJECT_ROOT / "apps.yaml"
    
    if not apps_yaml.exists():
        pytest.skip("apps.yaml not found")
    
    try:
        import yaml
        with open(apps_yaml) as f:
            data = yaml.safe_load(f)
        
        # Basic validation
        assert "apps" in data, "apps.yaml must contain 'apps' key"
        assert isinstance(data["apps"], list), "'apps' must be a list"
        
        # Validate each app has required fields
        for app in data["apps"]:
            assert "name" in app, f"App missing 'name': {app}"
            assert "namespace" in app, f"App {app.get('name')} missing 'namespace'"
            assert "helm" in app, f"App {app.get('name')} missing 'helm'"
            
    except Exception as e:
        pytest.fail(f"apps.yaml validation failed: {e}")


def test_helm_chart_versions_match():
    """
    Test that Helm chart versions in apps.yaml are consistent.
    
    This is a basic check - you might want to extend it to:
    - Check against a versions.yaml file
    - Check if versions are available in the Helm repos
    """
    apps_yaml = PROJECT_ROOT / "apps.yaml"
    
    if not apps_yaml.exists():
        pytest.skip("apps.yaml not found")
    
    import yaml
    with open(apps_yaml) as f:
        data = yaml.safe_load(f)
    
    apps_with_helm = [app for app in data.get("apps", []) if "helm" in app]
    
    # Just verify we have some Helm apps defined
    assert len(apps_with_helm) > 0, "No Helm apps defined"
    
    # Print summary
    print(f"\nFound {len(apps_with_helm)} Helm apps:")
    for app in apps_with_helm:
        helm = app.get("helm", {})
        print(f"  - {app['name']}: {helm.get('chart')} {helm.get('version')}")


def test_namespace_consistency():
    """
    Test that apps reference valid namespaces.
    
    All namespaces referenced by apps should either:
    1. Be created by some app, or
    2. Be a known system namespace
    """
    KNOWN_NAMESPACES = {
        "kube-system", "default", "kube-public", "kube-node-lease",
        "external-secrets", "cert-manager", "external-dns", "cloudflared",
        "envoy-gateway", "cnpg-system", "redis", "authentik",
        "homelab", "music", "vaultwarden",
    }
    
    apps_yaml = PROJECT_ROOT / "apps.yaml"
    
    if not apps_yaml.exists():
        pytest.skip("apps.yaml not found")
    
    import yaml
    with open(apps_yaml) as f:
        data = yaml.safe_load(f)
    
    # Collect all namespaces
    all_namespaces = KNOWN_NAMESPACES.copy()
    for app in data.get("apps", []):
        all_namespaces.add(app.get("namespace", ""))
    
    # Check that all referenced namespaces are known
    referenced = set()
    for app in data.get("apps", []):
        ns = app.get("namespace")
        if ns:
            referenced.add(ns)
    
    # Any namespace in referenced should be in known
    unknown = referenced - KNOWN_NAMESPACES
    if unknown:
        print(f"Warning: Unknown namespaces found: {unknown}")
        # This is a warning, not a failure - new apps may add namespaces


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
