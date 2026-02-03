# =============================================================================
# Import blocks for existing OCI resources
# These resources were created manually or by a previous Terraform run
# and need to be imported into the current state
# =============================================================================

# Budget (only 1 allowed per compartment in free tier)
import {
  to = oci_budget_budget.homelab
  id = "ocid1.budget.oc1.eu-paris-1.amaaaaaalyssediayh3qddzg6get57n2wjb7fxrcxamnszjrfvbkfxy23laq"
}

# Object Storage lifecycle policy
import {
  to = oci_identity_policy.object_storage_lifecycle
  id = "ocid1.policy.oc1..aaaaaaaanysn5g675252jpq4b3tcbzbnu7h32dhdt6oa6sa4b4ivh6uee3ca"
}

# Terraform state bucket
import {
  to = oci_objectstorage_bucket.tfstate
  id = "n/axnvxxurxefp/b/homelab-tfstate"
}

# Velero backups bucket
import {
  to = oci_objectstorage_bucket.velero_backups
  id = "n/axnvxxurxefp/b/homelab-velero-backups"
}
