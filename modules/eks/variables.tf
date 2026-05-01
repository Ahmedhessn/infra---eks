variable "cluster_name" {
  type        = string
  description = "EKS cluster name (unique in the region)."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets for worker nodes (and typical internal ENIs)."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnets (for EKS subnet tags and control-plane spread); must align with cluster_subnet_ids."
}

variable "cluster_subnet_ids" {
  type        = list(string)
  description = "All subnets (usually private + public) passed to the EKS control plane vpc_config; must span >=2 AZs."
}

variable "kubernetes_version" {
  type        = string
  description = "EKS control plane version (e.g. 1.30)."
}

variable "node_instance_types" {
  type        = list(string)
  description = "Instance types for the managed node group."
}

variable "node_desired_size" {
  type = number
}

variable "node_min_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

variable "endpoint_public_access" {
  type        = bool
  description = "If true, the Kubernetes API is reachable from the internet subject to public_access_cidrs."
  default     = true
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the public API endpoint when endpoint_public_access is true."
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the cluster and node group."
  default     = {}
}
