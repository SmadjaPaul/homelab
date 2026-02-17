# OKE Module Variables

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "cluster_name" {
  description = "OKE cluster name"
  type        = string
  default     = "homelab-oke"
}

variable "vcn_id" {
  description = "VCN OCID"
  type        = string
}

variable "lb_subnet_id" {
  description = "Load Balancer subnet OCID"
  type        = string
}

variable "worker_subnet_id" {
  description = "Worker subnet OCID"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.31.10"
}

variable "region" {
  description = "OCI region"
  type        = string
  default     = "eu-paris-1"
}

variable "node_ocpus" {
  description = "OCPUs per node"
  type        = number
  default     = 2
}

variable "node_memory" {
  description = "Memory in GB per node"
  type        = number
  default     = 12
}

variable "node_count" {
  description = "Number of nodes"
  type        = number
  default     = 2
}

variable "node_image_id" {
  description = "Node image OCID (Oracle Linux)"
  type        = string
  default     = "" # Will use latest Oracle Linux ARM
}

variable "ssh_public_key" {
  description = "SSH public key for worker nodes"
  type        = string
  default     = ""
}

variable "public_endpoint" {
  description = "Enable public endpoint"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Freeform tags"
  type        = map(string)
  default     = {}
}
