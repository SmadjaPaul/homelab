terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2024.12"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}
