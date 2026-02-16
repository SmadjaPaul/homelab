# OKE Module - Kubernetes Cluster

# Data: Availability Domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

# OKE Cluster (Basic - Free Tier)
resource "oci_containerengine_cluster" "oke" {
  compartment_id     = var.compartment_id
  name               = var.cluster_name
  vcn_id             = var.vcn_id
  kubernetes_version = var.kubernetes_version

  # Basic cluster (free) - no enhanced features
  options {
    service_lb_subnet_ids = [var.lb_subnet_id]

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }
  }

  endpoint_config {
    is_public_ip_enabled = var.public_endpoint
    subnet_id            = var.lb_subnet_id
  }

  freeform_tags = var.tags
}

# Node Pool - ARM workers (Free Tier: 2 OCPU / 12GB each)
resource "oci_containerengine_node_pool" "workers" {
  compartment_id     = var.compartment_id
  cluster_id         = oci_containerengine_cluster.oke.id
  name               = "${var.cluster_name}-workers"
  kubernetes_version = var.kubernetes_version

  # Shape: VM.Standard.A1.Flex (ARM)
  node_shape = "VM.Standard.A1.Flex"

  # 2 OCPU / 12GB per node
  node_shape_config {
    ocpus         = var.node_ocpus
    memory_in_gbs = var.node_memory
  }

  # 2 nodes (total 4 OCPU / 24GB)
  node_config_details {
    size = var.node_count

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = var.worker_subnet_id
    }
  }

  # Node source: Oracle Linux image
  node_source_details {
    source_type = "IMAGE"
    image_id    = var.node_image_id
  }

  # Labels for ARM nodes
  node_labels = {
    "kubernetes.io/arch" = "arm64"
  }

  freeform_tags = var.tags
}

# =============================================================================
# Outputs
# =============================================================================

output "cluster_id" {
  value = oci_containerengine_cluster.oke.id
}

output "cluster_name" {
  value = oci_containerengine_cluster.oke.name
}

output "cluster_endpoint" {
  value = oci_containerengine_cluster.oke.endpoints[0].public_endpoint
}

output "cluster_private_endpoint" {
  value = oci_containerengine_cluster.oke.endpoints[0].private_endpoint
}

output "node_pool_id" {
  value = oci_containerengine_node_pool.workers.id
}

output "kubeconfig_command" {
  value = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.oke.id} --file $HOME/.kube/config --region ${var.region} --token-version 2.0.0"
}
