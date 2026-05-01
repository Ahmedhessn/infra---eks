provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "backup"
  region = var.backup_bucket_region
}

