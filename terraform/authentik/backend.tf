terraform {
  backend "oci" {
    bucket    = "homelab-tfstate"
    namespace = "axnvxxurxefp"
    key       = "authentik/terraform.tfstate"
    region    = "eu-paris-1"
  }
}
