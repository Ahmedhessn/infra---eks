output "network" {
  value = {
    vpc_id             = module.vpc.vpc_id
    private_subnet_ids = module.vpc.private_subnet_ids
    public_subnet_ids  = module.vpc.public_subnet_ids
  }
}

output "ecr" {
  value = {
    repository_url = module.ecr.repository_url
    repository_arn = module.ecr.repository_arn
  }
}

output "k8s" {
  value = {
    security_group_id = module.k8s.security_group_id
    instances         = module.k8s.instances
  }
}

