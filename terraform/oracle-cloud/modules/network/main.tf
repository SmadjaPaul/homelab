# Network Module - VCN, Subnets, Security Lists, NAT Gateway

# Virtual Cloud Network
resource "oci_core_vcn" "homelab" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = var.vcn_name
  dns_label      = var.vcn_name

  freeform_tags = var.tags
}

# Internet Gateway
resource "oci_core_internet_gateway" "homelab" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab.id
  display_name   = "${var.vcn_name}-igw"
  enabled        = true

  freeform_tags = var.tags
}

# NAT Gateway (for private subnet outbound)
resource "oci_core_nat_gateway" "homelab" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab.id
  display_name   = "${var.vcn_name}-nat"
  block_traffic  = false

  freeform_tags = var.tags
}

# Service Gateway (for OCI services)
resource "oci_core_service_gateway" "homelab" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab.id
  display_name   = "${var.vcn_name}-service-gw"
  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }

  freeform_tags = var.tags
}

# Data: OCI Services
data "oci_core_services" "all_services" {}

# Public Route Table
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab.id
  display_name   = "${var.vcn_name}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.homelab.id
  }

  freeform_tags = var.tags
}

# Private Route Table (for OKE workers)
resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab.id
  display_name   = "${var.vcn_name}-private-rt"

  # Outbound via NAT
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.homelab.id
  }

  # OCI services via Service Gateway
  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.homelab.id
  }

  freeform_tags = var.tags
}

# =============================================================================
# Security List - Public Subnet
# =============================================================================

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab.id
  display_name   = "${var.vcn_name}-public-sl"

  # Egress - Allow all outbound
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # Internal VCN traffic
  ingress_security_rules {
    protocol    = "all"
    source      = var.vcn_cidr
    description = "Internal VCN traffic"
  }

  # ICMP for diagnostics
  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    description = "ICMP - Path MTU Discovery"
    icmp_options {
      type = 3
      code = 4
    }
  }

  freeform_tags = var.tags
}

# =============================================================================
# Security List - Private Subnet (for OKE workers)
# =============================================================================

resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab.id
  display_name   = "${var.vcn_name}-private-sl"

  # Egress - Allow all outbound via NAT
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # Internal VCN traffic
  ingress_security_rules {
    protocol    = "all"
    source      = var.vcn_cidr
    description = "Internal VCN traffic"
  }

  # SSH from VCN only
  ingress_security_rules {
    protocol    = "6"
    source      = var.vcn_cidr
    description = "SSH from VCN"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # NodePort for Comet (30080)
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "Comet streaming NodePort"
    tcp_options {
      min = 30080
      max = 30080
    }
  }

  freeform_tags = var.tags
}

# =============================================================================
# Subnets
# =============================================================================

# Public Subnet
resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.homelab.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "${var.vcn_name}-public-subnet"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false

  freeform_tags = var.tags
}

# Private Subnet (for OKE workers)
resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.homelab.id
  cidr_block                 = var.private_subnet_cidr
  display_name               = "${var.vcn_name}-private-subnet"
  dns_label                  = "private"
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  prohibit_public_ip_on_vnic = true

  freeform_tags = var.tags
}

# =============================================================================
# Outputs
# =============================================================================

output "vcn_id" {
  value = oci_core_vcn.homelab.id
}

output "vcn_cidr" {
  value = var.vcn_cidr
}

output "public_subnet_id" {
  value = oci_core_subnet.public.id
}

output "private_subnet_id" {
  value = oci_core_subnet.private.id
}

output "nat_gateway_id" {
  value = oci_core_nat_gateway.homelab.id
}

output "internet_gateway_id" {
  value = oci_core_internet_gateway.homelab.id
}
