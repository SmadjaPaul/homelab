# Compute Instances for Oracle Cloud - Free Tier Optimized
# =========================================================
# Architecture: 4 VMs (4 OCPU / 24GB RAM)
#   - oci-hub:       Omni + Tailscale + Comet
#   - talos-cp-1:    K8s Control Plane
#   - talos-worker-1: K8s Worker (apps lourdes)
#   - talos-worker-2: K8s Worker (DB + apps)

# VM Hub - Omni + Tailscale + Comet (Streaming)
resource "oci_core_instance" "hub" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index % length(data.oci_identity_availability_domains.ads.availability_domains)].name
  display_name        = "oci-hub"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 4
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    display_name     = "oci-hub-vnic"
    hostname_label   = "oci-hub"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/templates/hub-cloud-init.sh", {
      tailscale_auth_key = var.tailscale_auth_key
      comet_enabled      = true
    }))
  }

  freeform_tags = merge(var.tags, {
    Role     = "hub"
    Services = "omni,tailscale,comet"
  })
}

# Hub VNIC
data "oci_core_vnic_attachments" "hub" {
  compartment_id = var.compartment_id
  instance_id    = oci_core_instance.hub.id
}

data "oci_core_vnic" "hub" {
  vnic_id = data.oci_core_vnic_attachments.hub.vnic_attachments[0].vnic_id
}

# Kubernetes Nodes - Talos Linux
locals {
  k8s_nodes = [
    { name = "talos-cp-1", ip = "10.0.1.10", ocpus = 1, memory = 6, disk = 50 },
    { name = "talos-worker-1", ip = "10.0.1.11", ocpus = 1, memory = 8, disk = 64 },
    { name = "talos-worker-2", ip = "10.0.1.12", ocpus = 1, memory = 6, disk = 64 }
  ]
}

resource "oci_core_instance" "k8s_node" {
  count = length(local.k8s_nodes)

  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[count.index % length(data.oci_identity_availability_domains.ads.availability_domains)].name
  display_name        = local.k8s_nodes[count.index].name
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = local.k8s_nodes[count.index].ocpus
    memory_in_gbs = local.k8s_nodes[count.index].memory
  }

  source_details {
    source_type             = "image"
    source_id               = var.talos_image_id != "" ? var.talos_image_id : data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = local.k8s_nodes[count.index].disk
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    private_ip       = local.k8s_nodes[count.index].ip
    display_name     = "${local.k8s_nodes[count.index].name}-vnic"
    hostname_label   = local.k8s_nodes[count.index].name
  }

  metadata = var.talos_image_id != "" ? {} : {
    ssh_authorized_keys = var.ssh_public_key
  }

  freeform_tags = merge(var.tags, {
    Role    = "kubernetes"
    Node    = local.k8s_nodes[count.index].name
    Cluster = "oci-hub"
  })
}

# K8s node VNICs
data "oci_core_vnic_attachments" "k8s_node" {
  count          = length(oci_core_instance.k8s_node)
  compartment_id = var.compartment_id
  instance_id    = oci_core_instance.k8s_node[count.index].id
}

data "oci_core_vnic" "k8s_node" {
  count   = length(oci_core_instance.k8s_node)
  vnic_id = data.oci_core_vnic_attachments.k8s_node[count.index].vnic_attachments[0].vnic_id
}
