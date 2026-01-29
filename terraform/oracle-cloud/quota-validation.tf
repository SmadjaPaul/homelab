# Oracle Cloud Always Free Tier Quota Validation
# This file ensures we never exceed the free tier limits

locals {
  # Always Free Tier Limits (ARM Ampere A1)
  free_tier_limits = {
    arm_ocpus        = 4      # Total OCPUs for ARM instances
    arm_memory_gb    = 24     # Total memory for ARM instances
    block_storage_gb = 200    # Total block storage
    boot_volume_gb   = 200    # Included in block storage
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
        percent   = round((local.total_resources.ocpus / local.free_tier_limits.arm_ocpus) * 100)
      }
      memory_gb = {
        used      = local.total_resources.memory
        limit     = local.free_tier_limits.arm_memory_gb
        remaining = local.free_tier_limits.arm_memory_gb - local.total_resources.memory
        percent   = round((local.total_resources.memory / local.free_tier_limits.arm_memory_gb) * 100)
      }
      storage_gb = {
        used      = local.total_resources.disk
        limit     = local.free_tier_limits.block_storage_gb
        remaining = local.free_tier_limits.block_storage_gb - local.total_resources.disk
        percent   = round((local.total_resources.disk / local.free_tier_limits.block_storage_gb) * 100)
      }
    }
    status = local.quota_validation.all_ok ? "✅ Within Free Tier limits" : "❌ Exceeds Free Tier limits"
  }
}
