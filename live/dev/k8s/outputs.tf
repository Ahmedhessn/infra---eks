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

output "ecr_repos" {
  description = "ECR repositories for dev workloads (one per service)."
  value = {
    apps = {
      repository_url = module.ecr.repository_url
      repository_arn = module.ecr.repository_arn
    }
    mysql = {
      repository_url = module.ecr_mysql.repository_url
      repository_arn = module.ecr_mysql.repository_arn
    }
    memcached = {
      repository_url = module.ecr_memcached.repository_url
      repository_arn = module.ecr_memcached.repository_arn
    }
    nginx = {
      repository_url = module.ecr_nginx.repository_url
      repository_arn = module.ecr_nginx.repository_arn
    }
    rabbitmq = {
      repository_url = module.ecr_rabbitmq.repository_url
      repository_arn = module.ecr_rabbitmq.repository_arn
    }
    tomcat = {
      repository_url = module.ecr_tomcat.repository_url
      repository_arn = module.ecr_tomcat.repository_arn
    }
  }
}

output "eks" {
  value = {
    cluster_name     = module.eks.cluster_name
    cluster_arn      = module.eks.cluster_arn
    cluster_endpoint = module.eks.cluster_endpoint
  }
}

output "configure_kubectl" {
  description = "Run locally after apply (replace region if needed)."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "monitoring" {
  description = "Prometheus + Grafana EC2 box (dev)."
  value = {
    instance_id = aws_instance.monitoring.id
    public_ip   = aws_instance.monitoring.public_ip
    grafana_url = "http://${aws_instance.monitoring.public_ip}:3000"
    prom_url    = "http://${aws_instance.monitoring.public_ip}:9090"
  }
}

output "backup_bucket" {
  description = "S3 bucket in a different region intended for cluster backups (e.g., Velero)."
  value = {
    name   = aws_s3_bucket.backup.bucket
    arn    = aws_s3_bucket.backup.arn
    region = var.backup_bucket_region
  }
}
