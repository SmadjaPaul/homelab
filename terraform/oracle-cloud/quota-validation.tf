# Oracle Cloud Always Free Tier Quota Validation
# This file ensures we never exceed the free tier limits
# Full list: https://www.oracle.com/cloud/free/

locals {
  # ============================================================
  # Oracle Cloud Always Free Tier Limits (Complete List)
  # ============================================================
  free_tier_limits = {
    # Compute - ARM (Ampere A1)
    arm_ocpus             = 4      # 3,000 OCPU hours/month = ~4 OCPUs continuous
    arm_memory_gb         = 24     # 18,000 GB hours/month = ~24 GB continuous
    
    # Compute - AMD (E2.1.Micro)
    amd_vms               = 2      # 2 VMs with 1/8 OCPU and 1GB each
    
    # Storage
    block_storage_gb      = 200    # 2 block volumes, 200 GB total
    block_volume_backups  = 5      # 5 volume backups
    object_storage_gb     = 20     # Standard + Infrequent + Archive combined
    archive_storage_gb    = 20     # Included in object storage total
    
    # Networking
    vcns                  = 2      # 2 VCNs with IPv4/IPv6
    load_balancer_count   = 1      # 1 flexible LB (10 Mbps)
    network_load_balancer = 1      # 1 network LB
    outbound_data_tb      = 10     # 10 TB/month egress
    vpn_connections       = 50     # 50 IPSec connections
    
    # Database
    autonomous_db         = 2      # 2 Autonomous DBs (ATP, ADW, JSON, or APEX)
    nosql_storage_gb      = 25     # 25 GB per table, up to 3 tables
    nosql_tables          = 3      # Max 3 NoSQL tables
    
    # Security
    bastions              = 5      # 5 OCI Bastions
    vault_keys            = 20     # 20 master encryption key versions
    vault_secrets         = 150    # 150 Vault secrets
    private_cas           = 5      # 5 Private CAs
    tls_certificates      = 150    # 150 private TLS certificates
    
    # Observability
    logging_gb            = 10     # 10 GB/month logging
    monitoring_datapoints = 500000000  # 500M ingestion datapoints
    email_per_day         = 100    # 100 emails/day
    notifications_https   = 1000000    # 1M notifications/month
  }

  # Calculate totals from our configuration
  management_resources = {
    ocpus  = var.management_vm.ocpus
    memory = var.management_vm.memory
    disk   = var.management_vm.disk
  }

  k8s_resources = {
    ocpus  = sum([for node in var.k8s_nodes : node.ocpus])
    memory = sum([for node in var.k8s_nodes : node.memory])
    disk   = sum([for node in var.k8s_nodes : node.disk])
  }

  total_resources = {
    ocpus  = local.management_resources.ocpus + local.k8s_resources.ocpus
    memory = local.management_resources.memory + local.k8s_resources.memory
    disk   = local.management_resources.disk + local.k8s_resources.disk
  }

  # Validation results
  quota_validation = {
    ocpus_ok  = local.total_resources.ocpus <= local.free_tier_limits.arm_ocpus
    memory_ok = local.total_resources.memory <= local.free_tier_limits.arm_memory_gb
    disk_ok   = local.total_resources.disk <= local.free_tier_limits.block_storage_gb
    all_ok    = local.total_resources.ocpus <= local.free_tier_limits.arm_ocpus && local.total_resources.memory <= local.free_tier_limits.arm_memory_gb && local.total_resources.disk <= local.free_tier_limits.block_storage_gb
  }
}

# Validation checks - Terraform will fail if any of these conditions are false
resource "terraform_data" "quota_check_ocpus" {
  lifecycle {
    precondition {
      condition     = local.total_resources.ocpus <= local.free_tier_limits.arm_ocpus
      error_message = <<-EOT
        ❌ FREE TIER LIMIT EXCEEDED: OCPUs
        
        Requested: ${local.total_resources.ocpus} OCPUs
        Limit:     ${local.free_tier_limits.arm_ocpus} OCPUs
        
        Breakdown:
        - Management VM: ${local.management_resources.ocpus} OCPUs
        - K8s Nodes:     ${local.k8s_resources.ocpus} OCPUs
        
        Please reduce OCPU allocation to stay within the Always Free tier.
      EOT
    }
  }
}

resource "terraform_data" "quota_check_memory" {
  lifecycle {
    precondition {
      condition     = local.total_resources.memory <= local.free_tier_limits.arm_memory_gb
      error_message = <<-EOT
        ❌ FREE TIER LIMIT EXCEEDED: Memory
        
        Requested: ${local.total_resources.memory} GB
        Limit:     ${local.free_tier_limits.arm_memory_gb} GB
        
        Breakdown:
        - Management VM: ${local.management_resources.memory} GB
        - K8s Nodes:     ${local.k8s_resources.memory} GB
        
        Please reduce memory allocation to stay within the Always Free tier.
      EOT
    }
  }
}

resource "terraform_data" "quota_check_storage" {
  lifecycle {
    precondition {
      condition     = local.total_resources.disk <= local.free_tier_limits.block_storage_gb
      error_message = <<-EOT
        ❌ FREE TIER LIMIT EXCEEDED: Block Storage
        
        Requested: ${local.total_resources.disk} GB
        Limit:     ${local.free_tier_limits.block_storage_gb} GB
        
        Breakdown:
        - Management VM: ${local.management_resources.disk} GB
        - K8s Nodes:     ${local.k8s_resources.disk} GB
        
        Please reduce storage allocation to stay within the Always Free tier.
      EOT
    }
  }
}

# Output quota status for visibility
output "quota_status" {
  description = "Oracle Cloud Always Free Tier quota status"
  value = {
    limits = local.free_tier_limits
    usage = {
      ocpus = {
        used      = local.total_resources.ocpus
        limit     = local.free_tier_limits.arm_ocpus
        remaining = local.free_tier_limits.arm_ocpus - local.total_resources.ocpus
         percent   = floor((local.total_resources.ocpus / local.free_tier_limits.arm_ocpus) * 100)
      }
      memory_gb = {
        used      = local.total_resources.memory
        limit     = local.free_tier_limits.arm_memory_gb
        remaining = local.free_tier_limits.arm_memory_gb - local.total_resources.memory
         percent   = floor((local.total_resources.memory / local.free_tier_limits.arm_memory_gb) * 100)
      }
      storage_gb = {
        used      = local.total_resources.disk
        limit     = local.free_tier_limits.block_storage_gb
        remaining = local.free_tier_limits.block_storage_gb - local.total_resources.disk
         percent   = floor((local.total_resources.disk / local.free_tier_limits.block_storage_gb) * 100)
      }
    }
    status = local.quota_validation.all_ok ? "✅ Within Free Tier limits" : "❌ Exceeds Free Tier limits"
  }
}
