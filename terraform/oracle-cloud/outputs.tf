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
  description = "Management VM details"
  value = {
    id         = oci_core_instance.management.id
    name       = oci_core_instance.management.display_name
    public_ip  = oci_core_instance.management.public_ip
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
    management = "ssh -i ~/.ssh/oci-homelab ubuntu@${oci_core_instance.management.public_ip}"
    k8s_nodes = [
      for node in oci_core_instance.k8s_node :
      "ssh -i ~/.ssh/oci-homelab ubuntu@${node.public_ip}"
    ]
  }
}
