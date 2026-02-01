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
    management = "ssh -i ~/.ssh/oci-homelab ubuntu@${data.oci_core_vnic.management.public_ip_address}"
    k8s_nodes = [
      for node in oci_core_instance.k8s_node :
      "ssh -i ~/.ssh/oci-homelab ubuntu@${node.public_ip}"
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
  value = {
    access_key = oci_identity_customer_secret_key.velero_s3_key.id
    secret_key = oci_identity_customer_secret_key.velero_s3_key.key
  }
}
