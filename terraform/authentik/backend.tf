terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "authentik/terraform.tfstate"
    # Endpoints and credentials should be passed via CLI/ENV or Doppler
  }
}
