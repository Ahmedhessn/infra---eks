variable "name" {
  type        = string
  description = "ECR repository name."
}

variable "immutable_tags" {
  type        = bool
  description = "Whether to enable immutable tags."
  default     = true
}

