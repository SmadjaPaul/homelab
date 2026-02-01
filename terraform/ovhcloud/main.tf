# OVHcloud Public Cloud - Object Storage (S3 3-AZ)
# Promo: 3 To offerts jusqu'au 31 janvier 2026
# https://www.ovhcloud.com/fr/public-cloud/prices/

terraform {
  required_version = ">= 1.0"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 2.0"
    }
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.ovh_s3]
    }
  }
}

# OVH API (Application Key + Consumer Key)
provider "ovh" {
  endpoint           = var.ovh_endpoint
  application_key    = var.ovh_application_key
  application_secret = var.ovh_application_secret
  consumer_key       = var.ovh_consumer_key
}

# AWS provider for S3-compatible Object Storage (bucket creation)
# Use ovh_s3_access_key / ovh_s3_secret_key (set after first apply for user+credential)
provider "aws" {
  alias  = "ovh_s3"
  region = var.s3_region

  skip_metadata_api_check     = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  access_key = var.ovh_s3_access_key
  secret_key = var.ovh_s3_secret_key

  endpoints {
    s3 = "https://s3.${var.s3_region}.io.cloud.ovh.net"
  }
}
