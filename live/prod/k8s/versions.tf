terraform {
  required_version = ">= 1.6.0"

  ## Remote backend placeholder.
  ## WHY: Allows `terraform init -backend-config <file>` to configure S3/DynamoDB remote state.
  ## HOW: The actual bucket/table/key values come from `backend.hcl` generated per environment.
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

