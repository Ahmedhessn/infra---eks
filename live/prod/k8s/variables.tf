variable "aws_region" {
  type        = string
  description = "AWS region."
  default     = "us-east-1"
}

variable "project" {
  type        = string
  description = "Project prefix."
  default     = "k8s-self-managed-503459125797"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "allowed_ssh_cidrs" {
  type    = list(string)
  default = []
}

variable "allowed_k8s_api_cidrs" {
  type    = list(string)
  default = []
}

