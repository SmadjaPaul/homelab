terraform {
  backend "s3" {
    bucket                      = "tofu"
    region                      = "us-east-1"
    key                         = "twingate.tfstate"
    endpoint                    = "https://s3.smadja.xyz"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    use_path_style              = true
    skip_s3_checksum            = true
    skip_metadata_api_check     = true
  }

  required_providers {
    twingate = {
      source  = "Twingate/twingate"
      version = "3.8.0"
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
data "doppler_secrets" "twingate" {
  project = "infrastructure"
  config  = "prd"
}

provider "twingate" {
  api_token = data.doppler_secrets.infrastructure.map.TWINGATE_API_TOKEN
  network   = "smadja"
}
