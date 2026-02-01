# Network Configuration for Oracle Cloud

# Virtual Cloud Network (VCN)
resource "oci_core_vcn" "homelab" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "homelab-vcn"
  dns_label      = "homelab"

  freeform_tags = var.tags
}

# Internet Gateway
resource "oci_core_internet_gateway" "homelab" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab.id
  display_name   = "homelab-igw"
  enabled        = true

  freeform_tags = var.tags
}

# Route Table
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab.id
  display_name   = "homelab-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.homelab.id
  }

  freeform_tags = var.tags
}

# Security List
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab.id
  display_name   = "homelab-public-sl"

  # Egress - Allow all outbound
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  # Ingress - SSH
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "SSH access"

    tcp_options {
      min = 22
      max = 22
    }
  }

  # Ingress - HTTP
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "HTTP"

    tcp_options {
      min = 80
      max = 80
    }
  }

  # Ingress - HTTPS
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "HTTPS"

    tcp_options {
      min = 443
      max = 443
    }
  }

  # Ingress - Omni UI (Story 1.3.2; put behind HTTPS reverse proxy in production)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "Omni API/UI"

    tcp_options {
      min = 8080
      max = 8080
    }
  }

  # Ingress - Kubernetes API
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "Kubernetes API"

    tcp_options {
      min = 6443
      max = 6443
    }
  }

  # Ingress - Talos API
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "Talos API"

    tcp_options {
      min = 50000
      max = 50001
    }
  }

  # Ingress - ICMP (ping)
  ingress_security_rules {
    protocol    = "1" # ICMP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "ICMP"

    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    protocol    = "1" # ICMP
    source      = "10.0.0.0/16"
    stateless   = false
    description = "ICMP from VCN"

    icmp_options {
      type = 3
    }
  }

  freeform_tags = var.tags
}

# Public Subnet
resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.homelab.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "homelab-public-subnet"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false

  freeform_tags = var.tags
}
