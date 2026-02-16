# Outputs for Oracle Cloud Infrastructure

# Compartment and Network
output "compartment_id" {
  description = "OCI compartment OCID (useful for other Terraform modules)"
  value       = var.compartment_id
}

output "vcn_id" {
  description = "VCN OCID"
  value       = oci_core_vcn.homelab.id
}

output "subnet_id" {
  description = "Public subnet OCID"
  value       = oci_core_subnet.public.id
}

# Hub VM (Omni + Tailscale + Comet)
output "hub_vm" {
  description = "Hub VM details (Omni + Tailscale + Comet)"
  value = {
    id         = oci_core_instance.hub.id
    name       = oci_core_instance.hub.display_name
    public_ip  = data.oci_core_vnic.hub.public_ip_address
    private_ip = data.oci_core_vnic.hub.private_ip_address
    services   = "omni,tailscale,comet"
  }
}

output "hub_public_ip" {
  description = "Public IP of the OCI Hub VM"
  value       = data.oci_core_vnic.hub.public_ip_address
}

output "hub_private_ip" {
  description = "Private IP of the OCI Hub VM"
  value       = data.oci_core_vnic.hub.private_ip_address
}

# Kubernetes Nodes
output "k8s_nodes" {
  description = "Kubernetes Talos nodes details"
  value = [
    for idx, node in oci_core_instance.k8s_node : {
      id         = node.id
      name       = node.display_name
      public_ip  = length(data.oci_core_vnic.k8s_node) > idx ? data.oci_core_vnic.k8s_node[idx].public_ip_address : null
      private_ip = node.private_ip
      role       = idx == 0 ? "control-plane" : "worker"
    }
  ]
}

output "k8s_control_plane_ip" {
  description = "Private IP of K8s Control Plane (talos-cp-1)"
  value       = "10.0.1.10"
}

output "k8s_worker_ips" {
  description = "Private IPs of K8s Worker nodes"
  value       = ["10.0.1.11", "10.0.1.12"]
}

# Legacy output for compatibility
output "management_vm" {
  description = "Management VM details (alias for hub_vm)"
  value = {
    id         = oci_core_instance.hub.id
    name       = oci_core_instance.hub.display_name
    public_ip  = data.oci_core_vnic.hub.public_ip_address
    private_ip = data.oci_core_vnic.hub.private_ip_address
  }
}

# SSH Connections
output "ssh_connection_hub" {
  description = "SSH connection string for Hub VM"
  value       = "ssh ubuntu@${data.oci_core_vnic.hub.public_ip_address}"
}

output "ssh_connection_commands" {
  description = "SSH commands to connect to instances"
  value = {
    hub = data.oci_core_vnic.hub.public_ip_address != null ? "ssh -i ~/.ssh/oci-homelab ubuntu@${data.oci_core_vnic.hub.public_ip_address}" : "Hub VM not yet created"
    k8s_nodes = [
      for idx, node in oci_core_instance.k8s_node : (
        length(data.oci_core_vnic.k8s_node) > idx && data.oci_core_vnic.k8s_node[idx].public_ip_address != null
        ? "ssh -i ~/.ssh/oci-homelab ubuntu@${data.oci_core_vnic.k8s_node[idx].public_ip_address} # ${node.display_name}"
        : "Node ${node.display_name} not yet created"
      )
    ]
  }
}

# Omni Endpoints
output "omni_endpoint" {
  description = "Omni Web UI endpoint"
  value       = "https://${data.oci_core_vnic.hub.public_ip_address}:50001"
}

output "omni_grpc_endpoint" {
  description = "Omni gRPC endpoint for talosctl"
  value       = "${data.oci_core_vnic.hub.public_ip_address}:50000"
}

# Talos Configuration
output "talos_nodes_config" {
  description = "Configuration for Omni cluster template"
  value = {
    control_plane = {
      name = "talos-cp-1"
      ip   = "10.0.1.10"
    }
    workers = [
      { name = "talos-worker-1", ip = "10.0.1.11" },
      { name = "talos-worker-2", ip = "10.0.1.12" }
    ]
  }
}

# Object Storage
output "tfstate_bucket" {
  description = "Terraform state bucket (backend OCI)"
  value = {
    name      = oci_objectstorage_bucket.tfstate.name
    namespace = data.oci_objectstorage_namespace.ns.namespace
    region    = var.region
  }
}

output "velero_bucket" {
  description = "Velero backup bucket details"
  value = {
    name        = oci_objectstorage_bucket.velero_backups.name
    namespace   = data.oci_objectstorage_namespace.ns.namespace
    region      = var.region
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

# OCI Vault
output "vault_secrets" {
  description = "OCI Vault and secret OCIDs"
  value = {
    vault_id                  = oci_kms_vault.homelab_secrets.id
    vault_management_endpoint = oci_kms_vault.homelab_secrets.management_endpoint
    secrets = {
      cloudflare_api_token     = try(oci_vault_secret.cloudflare_api_token[0].id, null)
      omni_db_user             = try(oci_vault_secret.omni_db_user[0].id, null)
      omni_db_password         = try(oci_vault_secret.omni_db_password[0].id, null)
      omni_db_name             = try(oci_vault_secret.omni_db_name[0].id, null)
      oci_mgmt_ssh_private_key = try(oci_vault_secret.oci_mgmt_ssh_private_key[0].id, null)
      cloudflare_tunnel_token  = try(oci_vault_secret.cloudflare_tunnel_token[0].id, null)
      postgres_password        = try(oci_vault_secret.postgres_password[0].id, null)
      authentik_secret_key     = try(oci_vault_secret.authentik_secret_key[0].id, null)
      authentik_smtp_host      = try(oci_vault_secret.authentik_smtp_host[0].id, null)
      authentik_smtp_port      = try(oci_vault_secret.authentik_smtp_port[0].id, null)
      authentik_smtp_username  = try(oci_vault_secret.authentik_smtp_username[0].id, null)
      authentik_smtp_password  = try(oci_vault_secret.authentik_smtp_password[0].id, null)
      authentik_smtp_from      = try(oci_vault_secret.authentik_smtp_from[0].id, null)
    }
  }
}

# Summary
output "deployment_summary" {
  description = "Summary of deployed infrastructure"
  value       = <<-EOT

    🚀 OCI Infrastructure Deployed (Free Tier)
    ==========================================

    Hub VM (Omni + Tailscale + Comet):
      - Public IP: ${data.oci_core_vnic.hub.public_ip_address}
      - Private IP: ${data.oci_core_vnic.hub.private_ip_address}
      - Omni UI: https://${data.oci_core_vnic.hub.public_ip_address}:50001
      - Resources: 1 OCPU / 4GB RAM

    Kubernetes Cluster (3 VMs):
      - Control Plane (talos-cp-1): 10.0.1.10 (1 OCPU, 6GB)
      - Worker 1 (talos-worker-1):  10.0.1.11 (1 OCPU, 8GB)
      - Worker 2 (talos-worker-2):  10.0.1.12 (1 OCPU, 6GB)

    Total Resources: 4 OCPU / 24GB RAM ✅

    Next Steps:
    1. SSH to Hub: ssh ubuntu@${data.oci_core_vnic.hub.public_ip_address}
    2. Check Tailscale: sudo tailscale status
    3. Access Omni at https://${data.oci_core_vnic.hub.public_ip_address}:50001
    4. Configure Omni, generate Talos image
    5. Update 'talos_image_id' and apply Terraform
    6. Retrieve kubeconfig: omnictl kubeconfig -c oci-hub
    7. Deploy Flux: kubectl apply -k kubernetes/clusters/oci-hub

    EOT
}
