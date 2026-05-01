## WHY: Terraform remote state must be stored centrally so multiple people/CI can plan/apply safely.
## WHAT: An S3 bucket holds the `.tfstate` file; DynamoDB holds a lock record to prevent concurrent applies.
## HOW: We create an S3 bucket with versioning + encryption + public access block, plus a DynamoDB table.

resource "aws_s3_bucket" "tf_state" {
  ## WHAT: Dedicated bucket per env/project for Terraform state.
  ## HOW: Name derived from `var.project` so `dev` and `prod` can be separated cleanly.
  bucket = "${var.project}-tf-state"
}

resource "aws_s3_bucket_versioning" "tf_state" {
  ## WHY: Versioning allows state recovery if someone accidentally corrupts or overwrites state.
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  ## WHY: State can contain sensitive data (IPs, secrets from some providers). Encrypt at rest by default.
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      ## HOW: Use SSE-S3 (AES256). You can switch to SSE-KMS later if you need key control/audit.
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  ## WHY: State bucket must never be public.
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_locks" {
  ## WHY: Terraform uses a lock to prevent two applies at the same time (which can corrupt state).
  ## WHAT: A single-table lock with partition key `LockID`.
  name         = "${var.project}-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

