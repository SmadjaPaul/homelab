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
# With Cloudflare Tunnel, traffic is outbound-only; no need to open 80/443
# unless you run a direct reverse proxy on the VM. Set allow_public_http_https = false
# for tunnel-only (recommended). SSH is controlled by admin_ssh security list.
# Ref: https://dev.to/yoursunny/how-to-host-a-website-in-oracle-cloud-free-tier-5hca
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
  # PUBLIC HTTP/HTTPS (optional — not needed when using Cloudflare Tunnel only)
  # ==========================================================================

  dynamic "ingress_security_rules" {
    for_each = var.allow_public_http_https ? [1] : []
    content {
      protocol    = "6" # TCP
      source      = "0.0.0.0/0"
      stateless   = false
      description = "HTTP - direct access (disable for tunnel-only)"

      tcp_options {
        min = 80
        max = 80
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.allow_public_http_https ? [1] : []
    content {
      protocol    = "6" # TCP
      source      = "0.0.0.0/0"
      stateless   = false
      description = "HTTPS - direct access (disable for tunnel-only)"

      tcp_options {
        min = 443
        max = 443
      }
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
# SSH Access - Restricted to Admin IPs + GitHub Actions
# =============================================================================
# Separate security list for SSH to allow:
# 1. Admin IPs (your personal IP for manual access)
# 2. GitHub Actions IPs (for CI/CD deployments)
# Both lists are combined for the security rules.

locals {
  # Combine admin IPs + GitHub Actions IPs; or 0.0.0.0/0 if allow_ssh_from_anywhere (temporary)
  all_ssh_allowed_cidrs = var.allow_ssh_from_anywhere ? ["0.0.0.0/0"] : concat(
    var.admin_allowed_cidrs,
    var.github_actions_cidrs
  )
}

resource "oci_core_security_list" "admin_ssh" {
  count = var.enable_ssh_access && length(local.all_ssh_allowed_cidrs) > 0 ? 1 : 0

  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab.id
  display_name   = "homelab-admin-ssh-sl"

  # SSH from whitelisted IPs (admin + GitHub Actions)
  dynamic "ingress_security_rules" {
    for_each = local.all_ssh_allowed_cidrs
    content {
      protocol    = "6" # TCP
      source      = ingress_security_rules.value
      stateless   = false
      description = "SSH from ${contains(var.admin_allowed_cidrs, ingress_security_rules.value) ? "admin" : "GitHub Actions"}: ${ingress_security_rules.value}"

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
    var.enable_ssh_access && length(local.all_ssh_allowed_cidrs) > 0 ? [oci_core_security_list.admin_ssh[0].id] : []
  )
  prohibit_public_ip_on_vnic = false

  freeform_tags = var.tags
}
