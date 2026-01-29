# Variables for Oracle Cloud Infrastructure

variable "region" {
  description = "OCI region"
  type        = string
  default     = "eu-paris-1"
}

variable "compartment_id" {
  description = "OCI compartment OCID"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

# VCN Configuration
variable "vcn_cidr" {
  description = "CIDR block for VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# Instance Configuration
variable "management_vm" {
  description = "Management VM configuration (Omni, Keycloak)"
  type = object({
    name   = string
    ocpus  = number
    memory = number
    disk   = number
  })
  default = {
    name   = "oci-mgmt"
    ocpus  = 1
    memory = 6
    disk   = 50
  }
}

variable "k8s_nodes" {
  description = "Kubernetes nodes configuration"
  type = list(object({
    name   = string
    ocpus  = number
    memory = number
    disk   = number
  }))
  default = [
    {
      name   = "oci-node-1"
      ocpus  = 2
      memory = 12
      disk   = 64
    },
    {
      name   = "oci-node-2"
      ocpus  = 1
      memory = 6
      disk   = 75
    }
  ]
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "homelab"
    ManagedBy   = "terraform"
    Environment = "production"
  }
}
