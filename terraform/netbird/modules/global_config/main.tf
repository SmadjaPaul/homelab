terraform {
  required_providers {
    doppler = {
      source  = "DopplerHQ/doppler"
      version = ">= 1.0"
    }
  }
}

data "doppler_secrets" "this" {
  project = var.doppler_project
  config  = var.doppler_environment
}

output "netbird_api_key" {
  value     = data.doppler_secrets.this.map.NETBIRD_API_KEY
  sensitive = true
}
