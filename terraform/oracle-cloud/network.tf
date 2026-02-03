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

# =============================================================================
# Security List - Zero Trust Configuration
# =============================================================================
# Philosophy: No ports open to the world except HTTP/HTTPS (for Cloudflare Tunnel)
# All admin access goes through Twingate VPN or restricted IP whitelist
# =============================================================================

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab.id
  display_name   = "homelab-public-sl"

  # Egress - Allow all outbound (required for updates, Cloudflare Tunnel, etc.)
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  # ==========================================================================
  # PUBLIC ACCESS (Cloudflare Tunnel only)
  # ==========================================================================

  # Ingress - HTTP (for Cloudflare Tunnel / Let's Encrypt)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "HTTP - Cloudflare Tunnel"

    tcp_options {
      min = 80
      max = 80
    }
  }

  # Ingress - HTTPS (for Cloudflare Tunnel)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "HTTPS - Cloudflare Tunnel"

    tcp_options {
      min = 443
      max = 443
    }
  }

  # ==========================================================================
  # INTERNAL VCN TRAFFIC (between VMs)
  # ==========================================================================

  # Allow all traffic within VCN (K8s inter-node communication)
  ingress_security_rules {
    protocol    = "all"
    source      = var.vcn_cidr
    stateless   = false
    description = "Internal VCN traffic"
  }

  # ==========================================================================
  # ICMP (for network diagnostics)
  # ==========================================================================

  ingress_security_rules {
    protocol    = "1" # ICMP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "ICMP - Path MTU Discovery"

    icmp_options {
      type = 3
      code = 4
    }
  }

  freeform_tags = var.tags
}

# =============================================================================
# SSH Access - Restricted to Admin IPs only
# =============================================================================
# Separate security list for SSH to allow dynamic IP whitelisting
# If admin_allowed_cidrs is empty, SSH is only accessible via VCN (Twingate)

resource "oci_core_security_list" "admin_ssh" {
  count = var.enable_ssh_access && length(var.admin_allowed_cidrs) > 0 ? 1 : 0

  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab.id
  display_name   = "homelab-admin-ssh-sl"

  # SSH from whitelisted IPs only
  dynamic "ingress_security_rules" {
    for_each = var.admin_allowed_cidrs
    content {
      protocol    = "6" # TCP
      source      = ingress_security_rules.value
      stateless   = false
      description = "SSH from admin IP: ${ingress_security_rules.value}"

      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  freeform_tags = var.tags
}

# Public Subnet
resource "oci_core_subnet" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab.id
  cidr_block     = var.public_subnet_cidr
  display_name   = "homelab-public-subnet"
  dns_label      = "public"
  route_table_id = oci_core_route_table.public.id
  security_list_ids = concat(
    [oci_core_security_list.public.id],
    var.enable_ssh_access && length(var.admin_allowed_cidrs) > 0 ? [oci_core_security_list.admin_ssh[0].id] : []
  )
  prohibit_public_ip_on_vnic = false

  freeform_tags = var.tags
}
