#!/usr/bin/env python3
"""
Stack Management Script for Homelab Kubernetes Pulumi Stacks

This script manages the deployment of micro-stacks:
- k8s-core: Core infrastructure (namespaces, CRDs, operators)
- k8s-storage: Storage and databases (CSI, CNPG, Redis)
- k8s-apps: User applications

Usage:
    python scripts/stack_manager.py init          # Initialize all stacks
    python scripts/stack_manager.py up            # Deploy all stacks in order
    python scripts/stack_manager.py up core       # Deploy only k8s-core
    python scripts/stack_manager.py up storage    # Deploy only k8s-storage
    python scripts/stack_manager.py up apps       # Deploy only k8s-apps
    python scripts/stack_manager.py destroy       # Destroy all stacks
    python scripts/stack_manager.py status        # Show status of all stacks
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

# Base directory
BASE_DIR = Path(__file__).parent.parent
STACKS = ["k8s-core", "k8s-storage", "k8s-apps"]


def check_and_fix_pending_operations(stack_dir: Path, stack_name: str):
    """Detect pending operations in Pulumi state and auto-recover.

    Pending operations occur when a previous `pulumi up` was interrupted.
    This function cancels pending operations and refreshes state to recover.
    """
    # Check for pending operations by inspecting stack export
    try:
        result = subprocess.run(
            ["pulumi", "stack", "export"],
            cwd=stack_dir,
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            return

        import json

        state = json.loads(result.stdout)
        deployment = state.get("deployment", {})
        pending = deployment.get("pending_operations", [])

        if not pending:
            return

        print(f"\n⚠ Found {len(pending)} pending operation(s) in {stack_dir.name}:")
        for op in pending:
            op_type = op.get("type", "unknown")
            resource = op.get("resource", {}).get("urn", "unknown")
            print(f"  - {op_type}: {resource.split('::')[-1]}")

        print("  Auto-recovering: cancelling and refreshing state...")

        # Cancel pending operations
        subprocess.run(
            ["pulumi", "cancel", "--yes"],
            cwd=stack_dir,
            capture_output=True,
        )

        # Refresh state to reconcile with actual cluster state
        subprocess.run(
            ["pulumi", "refresh", "--non-interactive", "--yes"],
            cwd=stack_dir,
            env={
                **os.environ,
                "PYTHONPATH": str(BASE_DIR) + ":" + str(BASE_DIR.parent),
            },
            timeout=300,
        )
        print("  ✓ State recovered successfully")

    except (subprocess.TimeoutExpired, json.JSONDecodeError, Exception) as e:
        print(f"  ⚠ Could not auto-recover state: {e}")
        print("  You may need to run 'pulumi cancel' and 'pulumi refresh' manually.")


def run_pulumi(stack_dir: Path, args: list, env: dict = None):
    """Run a pulumi command in a specific stack directory.

    Args:
        env: Extra environment variables to merge into os.environ.
    """
    # Find pulumi binary - check venv first, then PATH
    venv_pulumi = stack_dir / ".venv" / "bin" / "pulumi"

    if not venv_pulumi.exists():
        # Fallback to system pulumi
        venv_pulumi = "pulumi"

    cmd = [str(venv_pulumi)] + args
    print(f"\n{'=' * 60}")
    print(f"Running: {' '.join(cmd)} in {stack_dir}")
    print(f"{'=' * 60}")

    # Build env: start from os.environ, merge extra vars if provided
    run_env = os.environ.copy()
    if env:
        run_env.update(env)
    # Add base directory and shared to PYTHONPATH so shared module can be imported
    run_env["PYTHONPATH"] = str(BASE_DIR) + ":" + str(BASE_DIR.parent)

    result = subprocess.run(cmd, cwd=stack_dir, env=run_env)
    return result.returncode


# =============================================================================
# PERFORMANCE OPTIMIZATIONS (TODO: enable when cluster is stable)
# =============================================================================
# These options can significantly speed up deployments but reduce granularity:
#
# --skip-preview: Skip the preview phase (saves ~30-60s)
# --refresh=false: Skip state refresh (saves ~10-30s, use only if no drift)
# --parallel=3: Limit parallel resource creation
#
# Example usage:
#   pulumi up --skip-preview --refresh=false --non-interactive --yes
#
# To enable, modify the run_pulumi call in cmd_up() to include these args:
#   args.extend(["--skip-preview", "--refresh=false"])
# =============================================================================


def run_preflight_check(cluster: str):
    """Run pre-flight checks before deployment."""
    print("\n" + "=" * 60)
    print("Running pre-flight checks...")
    print("=" * 60)

    # Run the preflight script
    preflight_script = BASE_DIR / "scripts" / "preflight.py"

    if not preflight_script.exists():
        print(f"Warning: {preflight_script} not found, skipping preflight")
        return True

    # Switch to cluster context first
    subprocess.run(["kubectl", "config", "use-context", cluster], capture_output=True)

    result = subprocess.run(
        [sys.executable, str(preflight_script), "--check-pvc", "--cluster", cluster],
        cwd=BASE_DIR,
        capture_output=True,
        text=True,
    )

    print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)

    if result.returncode != 0:
        print("\n⚠ Pre-flight checks failed!")
        print("Run with --skip-preflight to bypass")
        return False

    print("✓ Pre-flight checks passed")
    return True


def stack_init(stack_dir: Path, stack_name: str):
    """Initialize a stack."""
    print(f"\nInitializing stack: {stack_name}")

    # Check if stack exists
    result = subprocess.run(
        ["pulumi", "stack", "show", stack_name], cwd=stack_dir, capture_output=True
    )

    if result.returncode != 0:
        # Create stack
        run_pulumi(stack_dir, ["stack", "init", stack_name])
    else:
        print(f"  Stack {stack_name} already exists")


def cmd_init(args):
    """Initialize all stacks."""
    print("Initializing all stacks...")

    for stack in STACKS:
        stack_dir = BASE_DIR / stack
        stack_name = args.cluster

        if not stack_dir.exists():
            print(f"  Warning: {stack_dir} does not exist, skipping")
            continue

        stack_init(stack_dir, stack_name)

    print("\nAll stacks initialized!")


def cmd_up(args):
    """Deploy stacks."""
    stacks_to_deploy = []

    if args.stack == "all":
        stacks_to_deploy = STACKS
    elif args.stack == "core":
        stacks_to_deploy = ["k8s-core"]
    elif args.stack == "storage":
        stacks_to_deploy = ["k8s-storage"]
    elif args.stack == "apps":
        stacks_to_deploy = ["k8s-apps"]
    else:
        print(f"Unknown stack: {args.stack}")
        print(f"Valid options: {', '.join(STACKS)}, all")
        return 1

    # Run preflight checks unless disabled
    if not args.skip_preflight:
        if not run_preflight_check(args.cluster):
            if not args.force:
                print("\nAborting deployment due to preflight failures.")
                print(
                    "Use --force to deploy anyway or --skip-preflight to skip checks."
                )
                return 1
            else:
                print("\n⚠ Continuing with --force despite preflight failures!")

    for stack in stacks_to_deploy:
        stack_dir = BASE_DIR / stack
        stack_name = args.cluster

        if not stack_dir.exists():
            print(f"Warning: {stack_dir} does not exist, skipping")
            continue

        # Select stack
        run_pulumi(stack_dir, ["stack", "select", stack_name])

        # Auto-recover from interrupted deployments
        check_and_fix_pending_operations(stack_dir, stack_name)

        # Preview first
        if args.preview:
            run_pulumi(stack_dir, ["preview", "--non-interactive"])

        # Deploy
        if not args.preview_only:
            # Pre-deploy: port-forward + env injection for k8s-apps
            port_forward_proc = None
            extra_env = {}
            if stack == "k8s-apps":
                from authentik_lifecycle import (
                    start_port_forward,
                    stop_port_forward,
                    post_deploy_reconcile,
                )

                port_forward_proc = start_port_forward()

                # Inject AUTH0_USERS to avoid subprocess in authentik_registry.py
                try:
                    users = subprocess.check_output(
                        [
                            "doppler",
                            "secrets",
                            "get",
                            "AUTH0_USERS",
                            "--plain",
                            "--project",
                            "infrastructure",
                            "--config",
                            "prd",
                        ],
                        stderr=subprocess.DEVNULL,
                    ).decode()
                    extra_env["AUTH0_USERS"] = users
                except Exception:
                    pass

            try:
                run_pulumi(
                    stack_dir,
                    ["up", "--skip-preview", "--non-interactive", "--yes"],
                    env=extra_env if extra_env else None,
                )
            finally:
                if stack == "k8s-apps" and port_forward_proc:
                    stop_port_forward(port_forward_proc)

            # Post-deploy: outpost reconciliation for k8s-apps
            if stack == "k8s-apps":
                post_deploy_reconcile()

    return 0


def cmd_destroy(args):
    """Destroy stacks (in reverse order)."""
    stacks_to_destroy = list(reversed(STACKS))

    if args.stack != "all":
        if args.stack == "core":
            stacks_to_destroy = ["k8s-apps", "k8s-storage"]
        elif args.stack == "storage":
            stacks_to_destroy = ["k8s-apps"]
        elif args.stack == "apps":
            stacks_to_destroy = ["k8s-apps"]

    for stack in stacks_to_destroy:
        stack_dir = BASE_DIR / stack
        stack_name = args.cluster

        if not stack_dir.exists():
            continue

        # Select stack
        run_pulumi(stack_dir, ["stack", "select", stack_name])

        # Destroy
        run_pulumi(stack_dir, ["destroy", "--non-interactive", "--yes"])

    return 0


def cmd_status(args):
    """Show status of all stacks."""
    print(f"Stack Status (cluster: {args.cluster})")
    print("=" * 60)

    for stack in STACKS:
        stack_dir = BASE_DIR / stack

        if not stack_dir.exists():
            print(f"{stack}: DIRECTORY NOT FOUND")
            continue

        result = subprocess.run(
            ["pulumi", "stack", "output", "--json"],
            cwd=stack_dir,
            capture_output=True,
            text=True,
        )

        if result.returncode == 0:
            print(f"{stack}: OK")
            if args.verbose:
                print(result.stdout)
        else:
            print(f"{stack}: NOT INITIALIZED OR ERROR")
            if args.verbose:
                print(result.stderr)

    return 0


def main():
    parser = argparse.ArgumentParser(
        description="Manage Homelab Kubernetes Pulumi Stacks"
    )
    parser.add_argument(
        "command",
        choices=["init", "up", "destroy", "status"],
        help="Command to execute",
    )
    parser.add_argument(
        "--stack", default="all", help="Stack to operate on: all, core, storage, apps"
    )
    parser.add_argument("--cluster", default="oci", help="Cluster name: oci, local")
    parser.add_argument(
        "--preview", action="store_true", help="Run preview before up/destroy"
    )
    parser.add_argument(
        "--preview-only", action="store_true", help="Only run preview, don't apply"
    )
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    parser.add_argument(
        "--skip-preflight",
        action="store_true",
        help="Skip pre-flight checks before deployment",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Force deployment even if preflight checks fail",
    )

    args = parser.parse_args()

    if args.command == "init":
        return cmd_init(args)
    elif args.command == "up":
        return cmd_up(args)
    elif args.command == "destroy":
        return cmd_destroy(args)
    elif args.command == "status":
        return cmd_status(args)

    return 0


if __name__ == "__main__":
    sys.exit(main())
