## ===============================
## Root stack: live/dev/bootstrap
## ===============================
## WHY: Before we can use a remote backend (S3 + DynamoDB), those backend resources must exist.
## WHAT: This stack creates *dev-only* remote state infrastructure:
##      - S3 bucket for Terraform state files
##      - DynamoDB table for state locking
## HOW: We call the `remote_state` module and pass a project+environment prefix.

module "remote_state" {
  ## FROM WHERE: Implementation lives in `infra/terraform/modules/remote_state`.
  source = "../../../modules/remote_state"

  ## WHY: Keep dev and prod remote state fully isolated.
  project = "${var.project}-${var.environment}"
}

