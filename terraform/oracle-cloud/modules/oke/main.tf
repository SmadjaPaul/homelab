# OKE Module - Kubernetes Cluster (Free Tier: Basic cluster, A1.Flex workers)

# Data: Availability Domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

# Data: OKE node pool options (images compatibles ARM + version K8s)
data "oci_containerengine_node_pool_option" "oke" {
  compartment_id        = var.compartment_id
  node_pool_option_id   = "all"
  node_pool_os_arch     = "aarch64" # VM.Standard.A1.Flex = ARM
  node_pool_k8s_version = var.kubernetes_version
}

# Image pour les nœuds : fournie ou première image OKE Oracle Linux ARM (safe si sources vide)
locals {
  _sources      = data.oci_containerengine_node_pool_option.oke.sources
  _default_id   = length(local._sources) > 0 ? local._sources[0].image_id : ""
  node_image_id = var.node_image_id != "" ? var.node_image_id : local._default_id
}

# OKE Cluster - Type Basic (free; Enhanced = $0.10/h)
resource "oci_containerengine_cluster" "oke" {
  compartment_id     = var.compartment_id
  name               = var.cluster_name
  vcn_id             = var.vcn_id
  kubernetes_version = var.kubernetes_version
  type               = "BASIC_CLUSTER"

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

  node_shape = "VM.Standard.A1.Flex"

  node_shape_config {
    ocpus         = var.node_ocpus
    memory_in_gbs = var.node_memory
  }

  node_config_details {
    size = var.node_count

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = var.worker_subnet_id
    }
  }

  node_source_details {
    source_type = "IMAGE"
    image_id    = local.node_image_id
  }

  ssh_public_key = var.ssh_public_key

  freeform_tags = var.tags
}

# =============================================================================
# Outputs
# =============================================================================

output "cluster_id" {
  value = oci_containerengine_cluster.oke.id
}

output "cluster_ocid" {
  value       = oci_containerengine_cluster.oke.id
  description = "Full cluster OCID"
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
