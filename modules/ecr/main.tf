## WHY: Kubernetes workloads need a private container registry to store/pull images.
## WHAT: ECR repository with scan-on-push and lifecycle policy to control storage costs.
## HOW: Create `aws_ecr_repository` and attach a JSON lifecycle policy.

resource "aws_ecr_repository" "this" {
  ## WHAT: Repository name, typically unique per env/app.
  name = var.name

  ## WHY: Immutable tags prevent "tag drift" (e.g., someone overwrites `:latest`).
  ## HOW: Set mutability based on `var.immutable_tags`.
  image_tag_mutability = var.immutable_tags ? "IMMUTABLE" : "MUTABLE"

  image_scanning_configuration {
    ## WHY: Basic security best practice (scan for known vulnerabilities).
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  ## WHY: Without a lifecycle policy, ECR can grow forever and increase cost.
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 50 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 50
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

