variable "aws_region" {
  type        = string
  description = "AWS region."
  default     = "us-east-1"
}

variable "project" {
  type        = string
  description = "Project prefix."
  default     = "k8s-emad-128768042813"
}

variable "environment" {
  type        = string
  description = "Environment name (dev/prod)."
  default     = "dev"
}

