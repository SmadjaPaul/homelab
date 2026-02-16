# OKE - Oracle Kubernetes Engine (Free Tier)
# Configuration optimisée pour Always Free
#
# Ressources utilisées:
# - 1 cluster OKE Basic (gratuit)
# - 2 workers VM.Standard.A1.Flex (2 OCPU / 12GB chacun)
# - Total: 4 OCPU / 24GB RAM / 200GB storage

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }

  # Backend configuration - use:
  #   terraform init -backend-config=backend.hcl
  # Or copy backend.hcl.example to backend.hcl and update with your namespace
  # backend "s3" {}
}

provider "oci" {
  region = var.region
}

# =============================================================================
# Data Sources
# =============================================================================

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# =============================================================================
# VCN et Réseau
# =============================================================================

resource "oci_core_vcn" "oke_vcn" {
  compartment_id = var.compartment_id
  cidr_block     = "10.0.0.0/16"
  display_name   = "oke-vcn"
  dns_label      = "okevcn"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-internet-gateway"
}

resource "oci_core_nat_gateway" "nat_gw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-nat-gateway"
}

resource "oci_core_service_gateway" "svc_gw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-service-gateway"
  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }
}

data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

# Route Table pour les workers (privé avec NAT)
resource "oci_core_route_table" "worker_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-worker-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat_gw.id
  }

  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.svc_gw.id
  }
}

# Route Table pour les load balancers (public)
resource "oci_core_route_table" "lb_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-lb-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# Subnet pour les workers (privé)
resource "oci_core_subnet" "worker_subnet" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.oke_vcn.id
  cidr_block                 = "10.0.10.0/24"
  display_name               = "oke-worker-subnet"
  dns_label                  = "workers"
  route_table_id             = oci_core_route_table.worker_rt.id
  prohibit_public_ip_on_vnic = true
  security_list_ids          = [oci_core_security_list.worker_sl.id]
}

# Subnet pour les load balancers (public)
resource "oci_core_subnet" "lb_subnet" {
  compartment_id    = var.compartment_id
  vcn_id            = oci_core_vcn.oke_vcn.id
  cidr_block        = "10.0.20.0/24"
  display_name      = "oke-lb-subnet"
  dns_label         = "lbsubnet"
  route_table_id    = oci_core_route_table.lb_rt.id
  security_list_ids = [oci_core_security_list.lb_sl.id]
}

# =============================================================================
# Security Lists
# =============================================================================

resource "oci_core_security_list" "worker_sl" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-worker-security-list"

  # Autoriser tout le trafic interne VCN
  ingress_security_rules {
    protocol    = "all"
    source      = "10.0.0.0/16"
    description = "Allow all from VCN"
  }

  # Comet NodePort (30080) - Exposé sur Internet
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Comet streaming NodePort"
    tcp_options {
      min = 30080
      max = 30080
    }
  }

  # SSH - Uniquement depuis le VCN (pas d'accès direct Internet)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "10.0.0.0/16"
    description = "SSH from VCN only"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Egress: tout autoriser
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all egress"
  }
}

resource "oci_core_security_list" "lb_sl" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-lb-security-list"

  # HTTP
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "HTTP"
    tcp_options {
      min = 80
      max = 80
    }
  }

  # HTTPS
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "HTTPS"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Egress: tout autoriser vers le VCN
  egress_security_rules {
    protocol    = "all"
    destination = "10.0.0.0/16"
    description = "Allow all to VCN"
  }
}

# =============================================================================
# Cluster OKE Basic (Gratuit)
# =============================================================================

resource "oci_containerengine_cluster" "homelab" {
  compartment_id     = var.compartment_id
  name               = "homelab-oke"
  vcn_id             = oci_core_vcn.oke_vcn.id
  kubernetes_version = var.kubernetes_version

  # Type Basic = Gratuit
  options {
    service_lb_subnet_ids = [oci_core_subnet.lb_subnet.id]

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }
  }

  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = oci_core_subnet.lb_subnet.id
  }

  freeform_tags = {
    "Environment" = "homelab"
    "ManagedBy"   = "terraform"
  }
}

# =============================================================================
# Node Pool (2 workers ARM)
# =============================================================================

resource "oci_containerengine_node_pool" "workers" {
  cluster_id     = oci_containerengine_cluster.homelab.id
  compartment_id = var.compartment_id
  name           = "workers"

  kubernetes_version = var.kubernetes_version
  node_shape         = "VM.Standard.A1.Flex"

  # Configuration shape: 2 OCPU / 12GB par node
  node_shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  node_config_details {
    # Taille: 2 nodes (total 4 OCPU / 24GB)
    size = 2

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = oci_core_subnet.worker_subnet.id
    }

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[1].name
      subnet_id           = oci_core_subnet.worker_subnet.id
    }
  }

  node_source_details {
    image_id    = data.oci_core_images.oracle_linux.images[0].id
    source_type = "IMAGE"
  }

  ssh_public_key = var.ssh_public_key

  freeform_tags = {
    "Environment" = "homelab"
    "NodePool"    = "workers"
  }
}

# =============================================================================
