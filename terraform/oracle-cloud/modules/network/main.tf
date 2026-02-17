# Network Module - VCN, Subnets, Security Lists, NAT Gateway, Bastion

# Data: OCI Services
data "oci_core_services" "all_services" {}

# Virtual Cloud Network
resource "oci_core_vcn" "vcn" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = var.vcn_name
  dns_label      = var.vcn_dns_label

  freeform_tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

# Internet Gateway
resource "oci_core_internet_gateway" "internet_gateway" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.vcn_name}-igw"
  enabled        = true

  freeform_tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

# NAT Gateway (for private subnet outbound)
resource "oci_core_nat_gateway" "nat_gateway" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.vcn_name}-nat"
  block_traffic  = false

  freeform_tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

# Service Gateway (for OCI services)
resource "oci_core_service_gateway" "service_gateway" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.vcn_name}-service-gw"
  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }

  freeform_tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

# Public Route Table
resource "oci_core_route_table" "public_route_table" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.vcn_name}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.internet_gateway.id
  }

  freeform_tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

# Private Route Table (for OKE workers)
resource "oci_core_route_table" "private_route_table" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.vcn_name}-private-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat_gateway.id
  }

  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.service_gateway.id
  }

  freeform_tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# Security List - Public Subnet
# =============================================================================

resource "oci_core_security_list" "public_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.vcn_name}-public-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol    = "all"
    source      = var.vcn_cidr
    description = "Internal VCN traffic"
  }

  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    description = "ICMP - Path MTU Discovery"
    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "Kubernetes API Server"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  freeform_tags = var.tags
}

# =============================================================================
# Security List - Private Subnet (for OKE workers)
# =============================================================================

resource "oci_core_security_list" "private_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.vcn_name}-private-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol    = "all"
    source      = var.vcn_cidr
    description = "Internal VCN traffic"
  }

  ingress_security_rules {
    protocol    = "6"
    source      = var.vcn_cidr
    description = "SSH from VCN"
    tcp_options {
      min = var.ssh_port
      max = var.ssh_port
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.allowed_ingress_ports
    content {
      protocol    = "6"
      source      = "0.0.0.0/0"
      description = "Allowed ingress port ${ingress_security_rules.value}"
      tcp_options {
        min = ingress_security_rules.value
        max = ingress_security_rules.value
      }
    }
  }

  # Cloudflare Tunnel access (HTTP/HTTPS from Cloudflare IPs only)
  dynamic "ingress_security_rules" {
    for_each = var.cloudflare_ips
    content {
      protocol    = "6"
      source      = ingress_security_rules.value
      description = "HTTPS from Cloudflare ${ingress_security_rules.value}"
      tcp_options {
        min = 443
        max = 443
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.cloudflare_ips
    content {
      protocol    = "6"
      source      = ingress_security_rules.value
      description = "HTTP from Cloudflare ${ingress_security_rules.value}"
      tcp_options {
        min = 80
        max = 80
      }
    }
  }

  freeform_tags = var.tags
}

# =============================================================================
# Subnets
# =============================================================================

resource "oci_core_subnet" "public_subnet" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.vcn.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "${var.vcn_name}-public-subnet"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public_route_table.id
  security_list_ids          = [oci_core_security_list.public_security_list.id]
  prohibit_public_ip_on_vnic = false

  freeform_tags = var.tags
}

resource "oci_core_subnet" "private_subnet" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.vcn.id
  cidr_block                 = var.private_subnet_cidr
  display_name               = "${var.vcn_name}-private-subnet"
  dns_label                  = "private"
  route_table_id             = oci_core_route_table.private_route_table.id
  security_list_ids          = [oci_core_security_list.private_security_list.id]
  prohibit_public_ip_on_vnic = true

  freeform_tags = var.tags
}

# =============================================================================
# OCI Bastion Service
# =============================================================================

resource "oci_bastion_bastion" "bastion" {
  count                        = var.bastion_enabled ? 1 : 0
  compartment_id               = var.compartment_id
  target_subnet_id             = oci_core_subnet.private_subnet.id
  bastion_type                 = "STANDARD"
  name                         = "${var.vcn_name}-bastion"
  client_cidr_block_allow_list = ["0.0.0.0/0"]

  freeform_tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "vcn_id" {
  value = oci_core_vcn.vcn.id
}

output "vcn_cidr" {
  value = var.vcn_cidr
}

output "public_subnet_id" {
  value = oci_core_subnet.public_subnet.id
}

output "private_subnet_id" {
  value = oci_core_subnet.private_subnet.id
}

output "nat_gateway_id" {
  value = oci_core_nat_gateway.nat_gateway.id
}

output "internet_gateway_id" {
  value = oci_core_internet_gateway.internet_gateway.id
}

output "service_gateway_id" {
  value = oci_core_service_gateway.service_gateway.id
}

output "public_route_table_id" {
  value = oci_core_route_table.public_route_table.id
}

output "private_route_table_id" {
  value = oci_core_route_table.private_route_table.id
}

output "public_security_list_id" {
  value = oci_core_security_list.public_security_list.id
}

output "private_security_list_id" {
  value = oci_core_security_list.private_security_list.id
}

output "bastion_id" {
  value = var.bastion_enabled ? oci_bastion_bastion.bastion[0].id : null
}
