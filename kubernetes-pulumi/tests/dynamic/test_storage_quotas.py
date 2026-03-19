import pytest
import subprocess
import json
import re
from kubernetes import client, config

# OCI Configuration from Pulumi
COMPARTMENT_ID = (
    "ocid1.tenancy.oc1..aaaaaaaamwy5a55i2ljjxildejy42z2zshzs3edjbevyl27q4iv52sqqaqna"
)
REGION = "eu-paris-1"


def parse_k8s_size(size_str):
    """Parses K8s size strings (e.g., '10Gi', '500Mi') to bytes."""
    units = {
        "Ki": 1024,
        "Mi": 1024**2,
        "Gi": 1024**3,
        "Ti": 1024**4,
        "Pi": 1024**5,
        "Ei": 1024**6,
        "k": 1000,
        "m": 1000**2,
        "g": 1000**3,
        "t": 1000**4,
        "p": 1000**5,
        "e": 1000**6,
    }
    match = re.match(r"^(\d+)([a-zA-Z]*)$", size_str)
    if not match:
        return 0
    number, unit = match.groups()
    return int(number) * units.get(unit, 1)


def get_oci_volumes():
    """Fetches all block volumes directly from OCI CLI."""
    cmd = [
        "oci",
        "bv",
        "volume",
        "list",
        "--compartment-id",
        COMPARTMENT_ID,
        "--region",
        REGION,
        "--output",
        "json",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        pytest.fail(f"Failed to query OCI CLI: {result.stderr}")
    return json.loads(result.stdout).get("data", [])


@pytest.mark.dynamic
def test_oci_ground_truth_quota():
    """
    CRITICAL TEST: Verify that the TOTAL OCI Block Storage usage (Ground Truth)
    is below the 200GB Always Free limit.
    """
    volumes = get_oci_volumes()

    total_gb = 0
    active_volumes = []

    for vol in volumes:
        # We count everything that is not 'TERMINATED', 'TERMINATING' or 'DELETING'
        if vol["lifecycle-state"] not in [
            "TERMINATED",
            "TERMINATING",
            "DELETING",
            "PROVISIONING",
            "RESTORING",
        ]:
            size_gb = vol["size-in-gbs"]
            total_gb += size_gb
            active_volumes.append(
                {
                    "id": vol["id"],
                    "state": vol["lifecycle-state"],
                    "size": size_gb,
                    "created": vol["time-created"],
                }
            )

    print("\n--- OCI Ground Truth Report ---")
    print(f"Total Active/Available Volumes: {len(active_volumes)}")
    print(f"Total Storage Costing Quota: {total_gb} GB")

    for v in active_volumes:
        print(f" - {v['id'][-8:]} ({v['state']}): {v['size']} GB")

    # Assert limit
    assert total_gb < 200, (
        f"OCI Storage usage EXCEEDS free tier: {total_gb} GB (Limit 200 GB)"
    )


@pytest.mark.dynamic
def test_k8s_oci_bv_orphans():
    """
    Check for PVCs/PVs in K8s that are 'Released' but still exist as OCI volumes.
    """
    config.load_kube_config()
    v1 = client.CoreV1Api()

    pvs = v1.list_persistent_volume().items

    # Group by storage class
    oci_pvs = [pv for pv in pvs if pv.spec.storage_class_name == "oci-bv"]

    released_oci_pvs = [pv for pv in oci_pvs if pv.status.phase == "Released"]

    if released_oci_pvs:
        print(
            f"\nWARNING: Found {len(released_oci_pvs)} 'Released' OCI PVs (Dead Storage):"
        )
        for pv in released_oci_pvs:
            print(f" - {pv.metadata.name} ({pv.spec.capacity['storage']})")

    # We allow some, but want to be alerted if it's too many
    assert len(released_oci_pvs) < 5, "Too many orphaned 'Released' PVs in K8s"


@pytest.mark.dynamic
def test_dead_oci_volumes_audit():
    """
    Check for OCI Volumes that exist in OCI but NOT as PVs in K8s.
    """
    config.load_kube_config()
    v1 = client.CoreV1Api()
    pvs = v1.list_persistent_volume().items

    # Extract all VolumeHandles from K8s PVs
    k8s_handles = set()
    for pv in pvs:
        if pv.spec.csi and pv.spec.csi.volume_handle:
            k8s_handles.add(pv.spec.csi.volume_handle)

    oci_volumes = get_oci_volumes()
    zombie_volumes = []

    for vol in oci_volumes:
        if vol["lifecycle-state"] == "AVAILABLE" and vol["id"] not in k8s_handles:
            zombie_volumes.append(vol)

    if zombie_volumes:
        print(
            f"\nCRITICAL: Found {len(zombie_volumes)} OCI Volumes NOT tracked by K8s (Zombies):"
        )
        for v in zombie_volumes:
            print(f" - {v['id']} ({v['size-in-gbs']} GB)")

    # Ideally 0
    assert len(zombie_volumes) == 0, (
        f"Found {len(zombie_volumes)} zombie volumes in OCI costing money!"
    )
