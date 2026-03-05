import os
import subprocess
import argparse
import sys


def cleanup_locks(pulumi_root):
    locks_dir = os.path.join(pulumi_root, ".pulumi", "locks")
    if not os.path.exists(locks_dir):
        # Check one level deeper if following the user's observed path
        locks_dir = os.path.join(pulumi_root, ".pulumi", ".pulumi", "locks")

    if os.path.exists(locks_dir):
        print(f"Cleaning up Pulumi locks in {locks_dir}...")
        try:
            # We want to delete the .json and .json.attrs files
            count = 0
            for root, dirs, files in os.walk(locks_dir):
                for file in files:
                    if file.endswith(".json") or file.endswith(".json.attrs"):
                        file_path = os.path.join(root, file)
                        os.remove(file_path)
                        count += 1
            print(f"Successfully removed {count} lock files.")
        except Exception as e:
            print(f"Error removing locks: {e}", file=sys.stderr)
    else:
        print(f"No locks directory found at {locks_dir}")


def cancel_pending_operations(stacks):
    """Attempt to run pulumi cancel for the given stacks."""
    for stack_path in stacks:
        if not os.path.isdir(stack_path):
            continue

        print(f"Checking for pending operations in {os.path.basename(stack_path)}...")
        # Note: This requires PULUMI_CONFIG_PASSPHRASE if applicable
        cmd = ["pulumi", "cancel", "--yes"]
        # We need to run it in the stack directory
        try:
            result = subprocess.run(cmd, cwd=stack_path, capture_output=True, text=True)
            if "error: no operation in progress" in result.stderr.lower():
                print(f"  No pending operations for {os.path.basename(stack_path)}.")
            elif result.returncode == 0:
                print(
                    f"  Successfully cancelled pending operations for {os.path.basename(stack_path)}."
                )
            else:
                print(
                    f"  Warning: Could not cancel operations: {result.stderr.strip()}"
                )
        except Exception as e:
            print(f"  Error running pulumi cancel: {e}")


def main():
    parser = argparse.ArgumentParser(
        description="Clean up Pulumi locks and pending operations."
    )
    parser.add_argument(
        "--root", default=".", help="Project root where .pulumi is located"
    )
    parser.add_argument(
        "--stacks", nargs="+", help="Stack directories to check for pending operations"
    )
    parser.add_argument(
        "--force", action="store_true", help="Force deletion of all lock files"
    )

    args = parser.parse_args()

    project_root = os.path.abspath(args.root)
    cleanup_locks(project_root)

    if args.stacks:
        cancel_pending_operations([os.path.abspath(s) for s in args.stacks])


if __name__ == "__main__":
    # Ensure we handle passphrase if needed via environment
    if "PULUMI_CONFIG_PASSPHRASE" not in os.environ:
        os.environ["PULUMI_CONFIG_PASSPHRASE"] = ""
    main()
