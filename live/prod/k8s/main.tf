## ==========================
## Root stack: live/prod/k8s
## ==========================
## Same idea as dev/k8s, but for production.
## WHY: Prod must be isolated from dev (network/cluster/registry/state).
## WHAT: A dedicated VPC + ECR + self-managed K8s cluster.
## HOW: Wiring to modules in `infra/terraform/modules/*`.

locals {
  ## Consistent prefix: `${project}-${environment}`.
  name = "${var.project}-${var.environment}"
}

module "vpc" {
  ## Builds the network (VPC/subnets/NAT).
  source = "../../../modules/vpc"

  name       = local.name
  cidr_block = var.vpc_cidr
}

module "ecr" {
  ## Builds the ECR repo for prod.
  source = "../../../modules/ecr"

  name = "${local.name}-apps"
}

module "k8s" {
  ## Builds self-managed K8s on EC2 (prod).
  source = "../../../modules/k8s_self_managed"

  name                  = local.name
  vpc_id                = module.vpc.vpc_id
  vpc_cidr              = var.vpc_cidr
  subnet_ids            = module.vpc.private_subnet_ids
  allowed_ssh_cidrs     = var.allowed_ssh_cidrs
  allowed_k8s_api_cidrs = var.allowed_k8s_api_cidrs

  ## Join command parameter per env.
  join_parameter_name = "/${local.name}/kubeadm/join"
}

