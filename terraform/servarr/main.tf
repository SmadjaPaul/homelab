# Terraform Servarr Module
# Configures Sonarr, Radarr, and Prowlarr via their respective providers
# Secrets are retrieved from Doppler

terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    bucket                      = "tofu"
    region                      = "us-east-1"
    key                         = "arr.tfstate"
    endpoint                    = "https://s3.smadja.xyz"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    use_path_style              = true
    skip_s3_checksum            = true
    skip_metadata_api_check     = true
  }

  required_providers {
    sonarr = {
      source  = "devopsarr/sonarr"
      version = "3.4.2"
    }
    prowlarr = {
      source  = "devopsarr/prowlarr"
      version = "3.2.0"
    }
    radarr = {
      source  = "devopsarr/radarr"
      version = "2.3.5"
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
data "doppler_secrets" "servarr" {
  project = "servarr"
  config  = "prd"
}

provider "sonarr" {
  url     = "http://sonarr-app.arr.svc.cluster.local:8989"
  api_key = data.doppler_secrets.servarr.map.SONARR_API_KEY
}

provider "radarr" {
  url     = "http://radarr-app.arr.svc.cluster.local:7878"
  api_key = data.doppler_secrets.servarr.map.RADARR_API_KEY
}

provider "prowlarr" {
  url     = "http://prowlarr-app.arr.svc.cluster.local:6767"
  api_key = data.doppler_secrets.servarr.map.PROWLARR_API_KEY
}
