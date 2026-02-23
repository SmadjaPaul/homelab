variable "proxmox_node" {
  type    = string
  default = "tatouine"
}

variable "storage_pool" {
  type    = string
  default = "nvme-vm"
}

variable "cluster_name" {
  type    = string
  default = "homelab"
}

variable "node_count" {
  type    = number
  default = 3
}

variable "vmid_start" {
  type    = number
  default = 100
}

variable "base_ip" {
  type    = string
  default = "192.168.68.100"
}

variable "gateway" {
  type    = string
  default = "192.168.68.1"
}

variable "subnet" {
  type    = number
  default = 24
}

variable "cpus" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 16384
}

variable "disk_size" {
  type    = number
  default = 50
}

variable "talos_version" {
  type    = string
  default = "1.12.0"
}

variable "talos_iso_arch" {
  type    = string
  default = "amd64"
}

variable "ssh_public_key" {
  type = string
}
