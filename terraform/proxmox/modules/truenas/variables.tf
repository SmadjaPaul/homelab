variable "proxmox_node" {
  type    = string
  default = "tatouine"
}

variable "fast_storage_pool" {
  type    = string
  default = "nvme-vm"
}

variable "data_storage_pool" {
  type    = string
  default = "tank-vm"
}

variable "vmid" {
  type    = number
  default = 300
}

variable "name" {
  type    = string
  default = "truenas"
}

variable "ip_address" {
  type = string
}

variable "cores" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 16384
}

variable "boot_disk_size" {
  type    = number
  default = 32
}

variable "data_disk_size" {
  type    = number
  default = 1000
}

variable "truenas_iso_file" {
  type    = string
  default = "local:iso/truenas-scale.iso"
}
