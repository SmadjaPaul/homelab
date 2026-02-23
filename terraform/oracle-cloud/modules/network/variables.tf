# Network Module Variables

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "vcn_name" {
  description = "VCN name prefix"
  type        = string
  default     = "homelab"
}

variable "vcn_dns_label" {
  description = "VCN DNS label (max 15 chars)"
  type        = string
  default     = "homelab"
}

variable "vcn_cidr" {
  description = "VCN CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR (for OKE workers)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "ssh_port" {
  description = "SSH port for ingress rules"
  type        = number
  default     = 22
}

variable "allowed_ingress_ports" {
  description = "List of ports allowed for ingress from anywhere"
  type        = list(number)
  default     = [30080, 6443]
}

variable "cloudflare_ips" {
  description = "Cloudflare IP ranges for allowlist"
  type        = list(string)
  default = [
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.0.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "172.64.0.0/13",
    "104.16.0.0/12",
  ]
}

variable "bastion_enabled" {
  description = "Enable OCI Bastion service"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Freeform tags"
  type        = map(string)
  default     = {}
}
