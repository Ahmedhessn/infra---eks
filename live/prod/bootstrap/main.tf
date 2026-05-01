## ================================
## Root stack: live/prod/bootstrap
## ================================
## WHY: Provision S3 + DynamoDB remote state for prod (fully isolated from dev).
## WHAT: Creates a prod-only state bucket + lock table.
## HOW: Call the `remote_state` module with a `${project}-${environment}` prefix.

module "remote_state" {
  source = "../../../modules/remote_state"

  project = "${var.project}-${var.environment}"
}

