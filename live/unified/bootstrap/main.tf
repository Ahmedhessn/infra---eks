## ===============================
## Root stack: live/unified/bootstrap
## ===============================
## WHY: Remote state bucket + lock for the **unified** EKS stack.
## WHAT: S3 + DynamoDB for Terraform state (`unified/k8s`).
##      - S3 bucket for Terraform state files
##      - DynamoDB table for state locking
## HOW: We call the `remote_state` module and pass a project+environment prefix.

module "remote_state" {
  ## FROM WHERE: Implementation lives in `infra/terraform/modules/remote_state`.
  source = "../../../modules/remote_state"

  ## WHY: Keep dev and prod remote state fully isolated.
  project = "${var.project}-${var.environment}"
}

