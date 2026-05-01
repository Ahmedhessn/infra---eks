terraform {
  required_version = ">= 1.6.0"

  ## Remote state for bootstrap (required for CI). Local: copy backend.hcl.example → backend.hcl
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

