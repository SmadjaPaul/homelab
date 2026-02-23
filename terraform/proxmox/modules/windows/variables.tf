variable "proxmox_node" {
  type    = string
  default = "tatouine"
}

variable "storage_pool" {
  type    = string
  default = "tank-vm"
}

variable "vmid" {
  type    = number
  default = 400
}

variable "name" {
  type    = string
  default = "windows-11"
}

variable "ip_address" {
  type = string
}

variable "cores" {
  type    = number
  default = 8
}

variable "memory" {
  type    = number
  default = 16384
}

variable "disk_size" {
  type    = number
  default = 256
}

variable "gpu_pci" {
  type    = string
  default = null
}

variable "windows_iso_file" {
  type    = string
  default = "tank-iso:iso/windows-11.iso"
}

variable "virtio_iso_file" {
  type    = string
  default = "tank-iso:iso/virtio-win.iso"
}
