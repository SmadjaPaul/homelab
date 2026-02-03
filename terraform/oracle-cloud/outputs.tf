# Outputs for Oracle Cloud Infrastructure

output "vcn_id" {
  description = "VCN OCID"
  value       = oci_core_vcn.homelab.id
}

output "subnet_id" {
  description = "Public subnet OCID"
  value       = oci_core_subnet.public.id
}

output "management_vm" {
  description = "Management VM details (public IP from VNIC)"
  value = {
    id         = oci_core_instance.management.id
    name       = oci_core_instance.management.display_name
    public_ip  = data.oci_core_vnic.management.public_ip_address
    private_ip = oci_core_instance.management.private_ip
  }
}

output "k8s_nodes" {
  description = "Kubernetes nodes details"
  value = [
    for idx, node in oci_core_instance.k8s_node : {
      id         = node.id
      name       = node.display_name
      public_ip  = node.public_ip
      private_ip = node.private_ip
    }
  ]
}

output "ssh_connection_commands" {
  description = "SSH commands to connect to instances"
  value = {
    management = data.oci_core_vnic.management.public_ip_address != null ? "ssh -i ~/.ssh/oci-homelab ubuntu@${data.oci_core_vnic.management.public_ip_address}" : "Management VM not yet created"
    k8s_nodes = [
      for node in oci_core_instance.k8s_node :
      node.public_ip != null ? "ssh -i ~/.ssh/oci-homelab ubuntu@${node.public_ip}" : "Node ${node.display_name} not yet created"
    ]
  }
}

# Object Storage output for Terraform state backend (namespace requis pour init)
output "tfstate_bucket" {
  description = "Terraform state bucket (backend OCI)"
  value = {
    name      = oci_objectstorage_bucket.tfstate.name
    namespace = data.oci_objectstorage_namespace.ns.namespace
    region    = var.region
  }
}

# Object Storage outputs for Velero
output "velero_bucket" {
  description = "Velero backup bucket details"
  value = {
    name      = oci_objectstorage_bucket.velero_backups.name
    namespace = data.oci_objectstorage_namespace.ns.namespace
    region    = var.region
    # S3 compatible endpoint
    s3_endpoint = "https://${data.oci_objectstorage_namespace.ns.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"
  }
}

output "velero_s3_credentials" {
  description = "S3 credentials for Velero (sensitive)"
  sensitive   = true
  value = var.user_ocid != "" ? {
    access_key = oci_identity_customer_secret_key.velero_s3_key[0].id
    secret_key = oci_identity_customer_secret_key.velero_s3_key[0].key
  } : null
}

# -----------------------------------------------------------------------------
# OCI Vault (secrets for CI)
# -----------------------------------------------------------------------------

output "vault_secrets" {
  description = "OCI Vault and secret OCIDs (for CI to fetch secrets via OCI CLI/API)"
  value = {
    vault_id                  = oci_kms_vault.homelab_secrets.id
    vault_management_endpoint = oci_kms_vault.homelab_secrets.management_endpoint
    secrets = {
      cloudflare_api_token     = try(oci_vault_secret.cloudflare_api_token[0].id, null)
      tfstate_dev_token        = try(oci_vault_secret.tfstate_dev_token[0].id, null)
      omni_db_user             = try(oci_vault_secret.omni_db_user[0].id, null)
      omni_db_password         = try(oci_vault_secret.omni_db_password[0].id, null)
      omni_db_name             = try(oci_vault_secret.omni_db_name[0].id, null)
      oci_mgmt_ssh_private_key = try(oci_vault_secret.oci_mgmt_ssh_private_key[0].id, null)
      # OCI Management Stack
      cloudflare_tunnel_token = try(oci_vault_secret.cloudflare_tunnel_token[0].id, null)
      postgres_password       = try(oci_vault_secret.postgres_password[0].id, null)
      authentik_secret_key    = try(oci_vault_secret.authentik_secret_key[0].id, null)
    }
  }
}
