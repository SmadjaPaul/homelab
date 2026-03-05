"""
Cluster configuration and kubeconfig management
"""

import json
import os
from pathlib import Path

import yaml
import pulumi
import pulumi_kubernetes as k8s


def load_kubeconfig_file(path: str) -> dict:
    """
    Load kubeconfig from file, supporting both JSON and YAML formats.
    """
    with open(path) as f:
        content = f.read()

    # Try JSON first
    try:
        return json.loads(content)
    except json.JSONDecodeError:
        pass

    # Try YAML
    try:
        return yaml.safe_load(content)
    except yaml.YAMLError:
        pass

    raise Exception(f"Unable to parse kubeconfig file: {path}")


def get_kubeconfig() -> str:
    """
    Get kubeconfig as JSON string from various sources.
    Priority: config file > environment > default
    """
    config = pulumi.Config()
    kubeconfig_path = config.get("kubeconfigPath")

    if kubeconfig_path and kubeconfig_path != "" and Path(kubeconfig_path).exists():
        kubeconfig = load_kubeconfig_file(kubeconfig_path)
        return json.dumps(kubeconfig)

    # Check environment variable
    kubeconfig_env = os.environ.get("KUBECONFIG")
    if kubeconfig_env and Path(kubeconfig_env).exists():
        kubeconfig = load_kubeconfig_file(kubeconfig_env)
        return json.dumps(kubeconfig)

    # Default: use kubectl default location
    default_path = Path(os.path.expanduser("~/.kube/config"))
    if default_path.exists():
        kubeconfig = load_kubeconfig_file(str(default_path))
        return json.dumps(kubeconfig)

    raise Exception(
        "No kubeconfig found. Set kubeconfigPath config or KUBECONFIG env var."
    )


def is_local_cluster() -> bool:
    """Determine if this is a local cluster based on stack name."""
    config = pulumi.Config()
    name = config.require("clusterName").lower()
    return name in ("local", "dev") or "home" in name or "talos" in name


def create_provider(
    name: str = None, kubeconfig: str = None, render_yaml_to_directory: str = None
) -> k8s.Provider:
    """
    Create Kubernetes provider for the current stack.
    """
    if name is None:
        config = pulumi.Config()
        name = config.require("clusterName")

    if kubeconfig is None:
        kubeconfig = get_kubeconfig()

    return k8s.Provider(
        name,
        kubeconfig=kubeconfig,
        render_yaml_to_directory=render_yaml_to_directory,
        enable_server_side_apply=True,
    )


def create_provider_from_kubeconfig(name: str, kubeconfig: dict) -> k8s.Provider:
    """
    Create a named Kubernetes provider from kubeconfig dict.
    """
    kubeconfig_str = json.dumps(kubeconfig)
    return k8s.Provider(
        name,
        kubeconfig=kubeconfig_str,
        enable_server_side_apply=True,
    )


def is_audit_mode() -> bool:
    """
    Check if running in audit mode (YAML generation only without cluster).

    Enable via PULUMI_AUDIT_MODE=true environment variable.
    """
    import os

    return os.environ.get("PULUMI_AUDIT_MODE", "").lower() == "true"
