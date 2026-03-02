#!/usr/bin/env python3
"""
Pre-flight Check Script

Performs pre-deployment checks to identify potential issues:
- Stale PVCs that could conflict with Helm adoption
- Missing CRDs
- Cluster connectivity issues

Usage:
    python scripts/preflight.py                    # Run all checks
    python scripts/preflight.py --check-pvc       # Check stale PVCs only
    python scripts/preflight.py --fix              # Auto-fix issues (PVC deletion)
    python scripts/preflight.py --dry-run          # Show what would be fixed
"""
import argparse
import subprocess
import sys
import json
from pathlib import Path


def run_cmd(cmd, capture=True, check=True):
    """Run a shell command and return output."""
    if isinstance(cmd, str):
        cmd = cmd.split()
    try:
        result = subprocess.run(
            cmd,
            capture_output=capture,
            text=True,
            check=check
        )
        return result.stdout.strip() if capture else ""
    except subprocess.CalledProcessError as e:
        if capture:
            print(f"Error: {e.stderr.strip()}")
        raise


def check_cluster_connectivity():
    """Verify cluster is accessible."""
    print("Checking cluster connectivity...")
    try:
        run_cmd("kubectl cluster-info", check=True)
        print("  ✓ Cluster is accessible")
        return True
    except subprocess.CalledProcessError:
        print("  ✗ Cannot connect to cluster")
        return False


def check_stale_pvcs():
    """
    Find PVCs managed by Pulumi but not tracked by Helm.
    These can cause Helm adoption failures.
    """
    print("\nChecking for stale PVCs...")
    
    try:
        # Get all PVCs with their managed-by label
        output = run_cmd(
            "kubectl get pvc -A -o json"
        )
    except subprocess.CalledProcessError:
        print("  ✗ Failed to get PVCs")
        return []
    
    try:
        pvcs = json.loads(output)
    except json.JSONDecodeError:
        print("  ✗ Failed to parse PVC JSON")
        return []
    
    stale = []
    for item in pvcs.get("items", []):
        labels = item.get("metadata", {}).get("labels", {})
        managed_by = labels.get("app.kubernetes.io/managed-by", "")
        phase = item.get("status", {}).get("phase", "")
        namespace = item.get("metadata", {}).get("namespace", "")
        name = item.get("metadata", {}).get("name", "")
        
        # Check if managed by Pulumi but NOT by Helm
        if managed_by == "pulumi":
            # Check if it has Helm release annotations
            annotations = item.get("metadata", {}).get("annotations", {})
            has_helm_name = "meta.helm.sh/release-name" in annotations
            has_helm_ns = "meta.helm.sh/release-namespace" in annotations
            
            if not (has_helm_name and has_helm_ns):
                stale.append(f"{namespace}/{name}")
                print(f"  ⚠ Stale PVC found: {namespace}/{name}")
                print(f"      - managed-by: {managed_by}")
                print(f"      - has Helm release-name: {has_helm_name}")
                print(f"      - has Helm release-ns: {has_helm_ns}")
                print(f"      - phase: {phase}")
    
    if not stale:
        print("  ✓ No stale PVCs found")
    else:
        print(f"\n  Found {len(stale)} stale PVC(s)")
    
    return stale


def fix_stale_pvcs(pvcs, dry_run=False):
    """Delete stale PVCs that could conflict with Helm."""
    if not pvcs:
        print("\nNo PVCs to fix")
        return
    
    print(f"\n{'[DRY RUN] ' if dry_run else ''}Fixing stale PVCs...")
    
    for pvc in pvcs:
        namespace, name = pvc.split("/")
        cmd = f"kubectl delete pvc {name} -n {namespace}"
        
        if dry_run:
            print(f"  Would delete: {pvc}")
        else:
            print(f"  Deleting: {pvc}")
            try:
                run_cmd(cmd, check=False)
                print(f"    ✓ Deleted {pvc}")
            except subprocess.CalledProcessError:
                print(f"    ✗ Failed to delete {pvc}")


def check_crds():
    """Check for required CRDs."""
    print("\nChecking required CRDs...")
    
    required_crds = [
        "externalsecrets.external-secrets.io",
        "clusters.postgresql.cnpg.io",
        "gatewayroutes.gateway.networking.k8s.io",
    ]
    
    all_present = True
    for crd in required_crds:
        try:
            run_cmd(f"kubectl get crd {crd}", check=True)
            print(f"  ✓ {crd}")
        except subprocess.CalledProcessError:
            print(f"  ✗ {crd} not found")
            all_present = False
    
    return all_present


def main():
    parser = argparse.ArgumentParser(description="Pre-flight checks for Kubernetes deployment")
    parser.add_argument("--check-pvc", action="store_true", help="Check stale PVCs only")
    parser.add_argument("--check-crd", action="store_true", help="Check CRDs only")
    parser.add_argument("--fix", action="store_true", help="Auto-fix issues (delete stale PVCs)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be fixed without making changes")
    parser.add_argument("--cluster", default="oci", help="Cluster context (default: oci)")
    
    args = parser.parse_args()
    
    print(f"Pre-flight checks for cluster: {args.cluster}")
    print("=" * 50)
    
    # Switch to correct context
    try:
        run_cmd(f"kubectl config use-context {args.cluster}", check=False)
    except:
        pass
    
    # Run checks
    if args.check_crd:
        check_crds()
        return
    
    if args.check_pvc:
        stale = check_stale_pvcs()
        if args.fix or args.dry_run:
            fix_stale_pvcs(stale, dry_run=args.dry_run)
        return
    
    # Run all checks
    connectivity_ok = check_cluster_connectivity()
    crds_ok = check_crds()
    stale_pvcs = check_stale_pvcs() if connectivity_ok else []
    
    print("\n" + "=" * 50)
    print("Summary:")
    print(f"  Cluster connectivity: {'✓' if connectivity_ok else '✗'}")
    print(f"  CRDs present: {'✓' if crds_ok else '✗'}")
    print(f"  Stale PVCs: {len(stale_pvcs)}")
    
    if stale_pvcs:
        print("\n⚠ WARNING: Stale PVCs detected!")
        print("   These can cause Helm adoption failures.")
        print(f"\n   Run with --fix to delete them automatically")
        print(f"   Or run with --dry-run to see what would be deleted")
        sys.exit(1)
    
    if not connectivity_ok:
        print("\n✗ Cluster not accessible")
        sys.exit(1)
    
    print("\n✓ All checks passed")


if __name__ == "__main__":
    main()
