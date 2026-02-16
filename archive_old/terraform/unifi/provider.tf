terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    bucket                      = "tofu"
    region                      = "us-east-1"
    key                         = "unifi.tfstate"
    endpoint                    = "https://s3.smadja.xyz"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    use_path_style              = true
    skip_s3_checksum            = true
    skip_metadata_api_check     = true
  }

  required_providers {
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "0.41.12"
    }
    doppler = {
      source  = "DopplerHQ/doppler"
      version = "1.13.0"
    }
  }
}

# Doppler provider - uses DOPPLER_TOKEN env var
provider "doppler" {}

# Fetch secrets from Doppler
data "doppler_secrets" "infrastructure" {
  project = "infrastructure"
  config  = "prd"
}

provider "unifi" {
  username       = "terraform"
  password       = data.doppler_secrets.infrastructure.map.UNIFI_PASSWORD
  api_url        = "https://10.0.0.1"
  allow_insecure = "true"
}
