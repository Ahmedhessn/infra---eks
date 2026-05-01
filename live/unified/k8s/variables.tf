variable "aws_region" {
  type        = string
  description = "AWS region for the single EKS cluster."
  default     = "us-east-1"
}

variable "project" {
  type        = string
  description = "Resource name prefix (lowercase for S3)."
  default     = "k8s-emad-128768042813"
}

variable "environment" {
  type        = string
  description = "Terraform stack label (remote state key). Workloads use K8s namespaces for dev/staging/prod."
  default     = "unified"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR for the shared cluster (distinct from legacy dev/staging stacks if those still exist)."
  default     = "10.30.0.0/16"
}

variable "eks_kubernetes_version" {
  type        = string
  description = "EKS control plane Kubernetes version."
  default     = "1.30"
}

variable "eks_node_instance_types" {
  type        = list(string)
  description = "Managed node group instance types."
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  type        = number
  description = "Desired worker count (spread across AZs by the ASG)."
  default     = 2
}

variable "eks_node_min_size" {
  type    = number
  default = 2
}

variable "eks_node_max_size" {
  type    = number
  default = 6
}

variable "eks_endpoint_public_access" {
  type        = bool
  description = "If true, EKS API reachable from the internet subject to eks_public_access_cidrs."
  default     = true
}

variable "eks_public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to use the public EKS endpoint."
  default     = ["0.0.0.0/0"]
}

variable "monitoring_instance_type" {
  type        = string
  description = "EC2 for Prometheus + Grafana (optional ops box)."
  default     = "t3.small"
}

variable "monitoring_access_cidrs" {
  type        = list(string)
  description = "CIDRs for Grafana (3000), Prometheus (9090), SSH (22)."
  default     = ["0.0.0.0/0"]
}

variable "monitoring_key_name" {
  type        = string
  description = "Optional EC2 key pair for the monitoring instance."
  default     = null
}

variable "backup_bucket_region" {
  type        = string
  description = "Region for Velero-style backup bucket."
  default     = "eu-west-1"
}

variable "backup_bucket_name" {
  type        = string
  description = "Optional explicit backup bucket name."
  default     = null
}
