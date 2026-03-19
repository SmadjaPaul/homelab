import pulumi


def validate_storage_quota(apps):
    """
    Validates that the total requested oci-bv storage does not exceed safe limits.
    OCI Free Tier is 200GB (Total including boot volumes).
    With 2 nodes (2 * 50GB boot volumes), we have exactly 100GB left for oci-bv.
    """
    total_oci_gb = 0
    quota_limit_gb = 100  # Adjusted for 2 nodes * 50GB boot volumes

    for app in apps:
        if not app.persistence.storage:
            continue

        for storage in app.persistence.storage:
            if storage.storage_class == "oci-bv":
                # Extract numeric value from size string (e.g., '10Gi' -> 10)
                try:
                    size_str = storage.size.lower()
                    if "gi" in size_str:
                        size = int(size_str.replace("gi", ""))
                    elif "mi" in size_str:
                        size = int(size_str.replace("mi", "")) / 1024
                    else:
                        size = int(size_str)

                    total_oci_gb += size
                except (ValueError, AttributeError):
                    pulumi.log.warn(
                        f"Could not parse storage size for {app.name}: {storage.size}"
                    )

    # Check for Redis in apps.yaml if it's not handled via standard storage models
    # (Some apps are purely Helm-based)
    # This is a bit tricky without full context of the final rendered values,
    # but we can look for "oci-bv" in helm values too if needed.

    if total_oci_gb > quota_limit_gb:
        raise Exception(
            f"⛔ STORAGE QUOTA EXCEEDED: Requested {total_oci_gb}Gi of OCI Block Storage (oci-bv). "
            f"Limit is set to {quota_limit_gb}Gi. "
            "Please use 'local-path' or 'hetzner-smb' instead."
        )

    if total_oci_gb > 0:
        pulumi.log.info(
            f"✅ OCI Storage Quota Check: {total_oci_gb}Gi requested (Safe)."
        )
