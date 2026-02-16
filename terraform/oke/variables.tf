# Variables for OKE (Oracle Kubernetes Engine) - Free Tier

variable "region" {
  description = "OCI Region (e.g., eu-paris-1)"
  type        = string
  default     = "eu-paris-1"
}

variable "tenancy_ocid" {
  description = "OCID of your OCI tenancy"
  type        = string
}

variable "compartment_id" {
  description = "OCID of the compartment where resources will be created"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the OKE cluster"
  type        = string
  default     = "v1.30.1"
}

variable "ssh_public_key" {
  description = "SSH public key for worker nodes (optional, for debugging)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "homelab"
}
