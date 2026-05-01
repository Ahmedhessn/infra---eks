variable "name" {
  type        = string
  description = "Name prefix for VPC resources."
}

variable "cidr_block" {
  type        = string
  description = "VPC CIDR."
}

variable "az_count" {
  type        = number
  description = "Number of AZs to span."
  default     = 2
}

variable "eks_cluster_name" {
  type        = string
  description = "Optional. When set, tag public/private subnets for EKS discovery and load balancers."
  default     = null
}

