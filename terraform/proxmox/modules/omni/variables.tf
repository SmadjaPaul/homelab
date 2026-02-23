variable "proxmox_node" {
  type    = string
  default = "tatouine"
}

variable "enable_omni" {
  type    = bool
  default = true
}

variable "start_on_boot" {
  type    = bool
  default = true
}

variable "template_vm_id" {
  type        = number
  default     = null
  description = "VM ID to clone from (template). Leave null to create from scratch."
}

variable "vmid" {
  type    = number
  default = 200
}

variable "cores" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 8192
}

variable "disk_size" {
  type    = number
  default = 50
}

variable "storage_pool" {
  type    = string
  default = "nvme-vm"
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "network_vlan_id" {
  type    = number
  default = 0
}

variable "ip_address" {
  type    = string
  default = "192.168.68.200"
}

variable "gateway" {
  type    = string
  default = "192.168.68.1"
}

variable "subnet_mask" {
  type    = string
  default = "24"
}
