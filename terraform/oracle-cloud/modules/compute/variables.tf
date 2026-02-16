# Compute Module Variables

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "vm_name" {
  description = "VM name"
  type        = string
  default     = "homelab-management"
}

variable "subnet_id" {
  description = "Subnet OCID"
  type        = string
}

variable "vm_ocpus" {
  description = "Number of OCPUs"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "Memory in GB"
  type        = number
  default     = 12
}

variable "vm_disk" {
  description = "Boot volume size in GB"
  type        = number
  default     = 50
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
  default     = ""
}

variable "assign_public_ip" {
  description = "Assign public IP"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Freeform tags"
  type        = map(string)
  default     = {}
}
