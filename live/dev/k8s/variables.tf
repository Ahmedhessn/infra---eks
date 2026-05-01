variable "aws_region" {
  type        = string
  description = "WHY: Region where Terraform will provision AWS resources. WHAT: Region name (e.g., us-east-1)."
  default     = "us-east-1"
}

variable "project" {
  type        = string
  description = "WHY: Consistent naming prefix for resources. WHAT: Prefix used in resource names (e.g., k8s-self-managed)."
  default     = "k8s-self-managed-503459125797"
}

variable "environment" {
  type        = string
  description = "WHY: Isolate dev from prod in names and state. WHAT: Environment name (dev here)."
  default     = "dev"
}

variable "vpc_cidr" {
  type        = string
  description = "WHY: Each environment needs a different CIDR to avoid overlap. WHAT: VPC CIDR for dev."
  default     = "10.20.0.0/16"
}

variable "eks_kubernetes_version" {
  type        = string
  description = "EKS control plane Kubernetes version."
  default     = "1.30"
}

variable "eks_node_instance_types" {
  type        = list(string)
  description = "Instance type(s) for the dev managed node group."
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  type        = number
  description = "Desired worker count for dev (use 1 for minimal cost)."
  default     = 2
}

variable "eks_node_min_size" {
  type    = number
  default = 2
}

variable "eks_node_max_size" {
  type    = number
  default = 3
}

variable "eks_endpoint_public_access" {
  type        = bool
  description = "SECURITY: If true, kubectl can reach the API from the internet when combined with eks_public_access_cidrs."
  default     = true
}

variable "eks_public_access_cidrs" {
  type        = list(string)
  description = "SECURITY: CIDRs allowed to use the public EKS endpoint. Tighten for non-dev."
  default     = ["0.0.0.0/0"]
}

variable "monitoring_instance_type" {
  type        = string
  description = "EC2 instance type for Prometheus + Grafana box."
  default     = "t3.small"
}

variable "monitoring_access_cidrs" {
  type        = list(string)
  description = "SECURITY: CIDRs allowed to access Grafana (3000) + Prometheus (9090) + SSH (22). Tighten to your public IP /32."
  default     = ["0.0.0.0/0"]
}

variable "monitoring_key_name" {
  type        = string
  description = "Optional EC2 key pair name to enable SSH access. Leave null to rely on SSM/instance connect (if configured)."
  default     = null
}

variable "backup_bucket_region" {
  type        = string
  description = "WHY: Store cluster backups in a different AWS region for DR. WHAT: Destination S3 bucket region (must NOT be an AZ)."
  default     = "eu-west-1"
}

variable "backup_bucket_name" {
  type        = string
  description = "WHY: Allow explicitly setting a globally-unique S3 bucket name for backups. WHAT: If null, a derived name will be used."
  default     = null
}
