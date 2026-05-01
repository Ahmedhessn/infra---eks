data "aws_caller_identity" "current" {}

locals {
  backup_bucket_name = coalesce(
    var.backup_bucket_name,
    lower(
      replace(
        format(
          "%s-velero-%s",
          substr(local.name, 0, 24),
          substr(md5("${data.aws_caller_identity.current.account_id}-${var.backup_bucket_region}-${local.name}"), 0, 8)
        ),
        "_",
        "-"
      )
    )
  )
}

resource "aws_s3_bucket" "backup" {
  provider = aws.backup
  bucket   = local.backup_bucket_name

  tags = {
    Name        = local.backup_bucket_name
    Environment = var.environment
    Project     = var.project
    Purpose     = "k8s-backups"
  }
}

resource "aws_s3_bucket_versioning" "backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.backup.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

