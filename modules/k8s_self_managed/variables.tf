variable "name" {
  type        = string
  description = "Cluster name/prefix."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for instances (usually private)."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR (used to restrict API access by default)."
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to SSH. Use empty list to disable SSH ingress."
  default     = []
}

variable "allowed_k8s_api_cidrs" {
  type        = list(string)
  description = "Additional CIDRs allowed to access Kubernetes API (6443). If empty, only VPC CIDR is allowed."
  default     = []
}

variable "instance_type_master" {
  type    = string
  default = "t3.medium"
}

variable "instance_type_worker" {
  type    = string
  default = "t3.medium"
}

variable "master_market_type" {
  type        = string
  description = "EC2 purchasing option for the master instance: on-demand or spot."
  default     = "on-demand"

  validation {
    condition     = contains(["on-demand", "spot"], var.master_market_type)
    error_message = "master_market_type must be one of: on-demand, spot."
  }
}

variable "worker_market_type" {
  type        = string
  description = "EC2 purchasing option for worker instances: on-demand or spot."
  default     = "on-demand"

  validation {
    condition     = contains(["on-demand", "spot"], var.worker_market_type)
    error_message = "worker_market_type must be one of: on-demand, spot."
  }
}

variable "worker_count" {
  type    = number
  default = 3
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for kubeadm (e.g. 1.30.0)."
  default     = "1.30.0"
}

variable "ssh_key_name" {
  type        = string
  description = "Optional EC2 key pair name. If null, no key will be attached."
  default     = null
}

variable "join_parameter_name" {
  type        = string
  description = "SSM Parameter Store name used to publish the kubeadm join command."
  default     = "/k8s/kubeadm/join"
}

