## =========================
## Root stack: live/dev/k8s
## =========================
## WHY: Dev environment entrypoint for Terraform in this folder.
## WHAT: VPC + ECR + **EKS** (managed control plane, one managed worker node for dev).
## HOW: Composes `vpc`, `ecr`, and `eks` modules.

locals {
  name         = "${var.project}-${var.environment}"
  cluster_name = "${local.name}-eks"
  ## WHY: EKS control plane expects subnets in multiple AZs; include public + private from the VPC module.
  eks_subnet_ids = sort(concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids))
}

module "vpc" {
  source = "../../../modules/vpc"

  name             = local.name
  cidr_block       = var.vpc_cidr
  az_count         = 2
  eks_cluster_name = local.cluster_name
}

module "ecr" {
  source = "../../../modules/ecr"

  name = "${local.name}-apps"
}

module "ecr_mysql" {
  source = "../../../modules/ecr"
  name   = "${local.name}-mysql"
}

module "ecr_memcached" {
  source = "../../../modules/ecr"
  name   = "${local.name}-memcached"
}

module "ecr_nginx" {
  source = "../../../modules/ecr"
  name   = "${local.name}-nginx"
}

module "ecr_rabbitmq" {
  source = "../../../modules/ecr"
  name   = "${local.name}-rabbitmq"
}

module "ecr_tomcat" {
  source = "../../../modules/ecr"
  name   = "${local.name}-tomcat"
}

module "eks" {
  source = "../../../modules/eks"

  cluster_name           = local.cluster_name
  private_subnet_ids     = module.vpc.private_subnet_ids
  public_subnet_ids      = module.vpc.public_subnet_ids
  cluster_subnet_ids     = local.eks_subnet_ids
  kubernetes_version     = var.eks_kubernetes_version
  node_instance_types    = var.eks_node_instance_types
  node_desired_size      = var.eks_node_desired_size
  node_min_size          = var.eks_node_min_size
  node_max_size          = var.eks_node_max_size
  endpoint_public_access = var.eks_endpoint_public_access
  public_access_cidrs    = var.eks_public_access_cidrs

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

## =========================
## Monitoring EC2 (Prometheus + Grafana)
## =========================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "monitoring" {
  name_prefix = "${local.name}-monitoring-"
  description = "Allow Grafana/Prometheus access for dev."
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.monitoring_access_cidrs
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.monitoring_access_cidrs
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.monitoring_access_cidrs
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name}-monitoring"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_instance" "monitoring" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.monitoring_instance_type
  subnet_id                   = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.monitoring.id]
  key_name                    = var.monitoring_key_name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/usr/bin/env bash
              set -euo pipefail

              export DEBIAN_FRONTEND=noninteractive

              apt-get update -y
              apt-get install -y ca-certificates curl gnupg lsb-release

              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              chmod a+r /etc/apt/keyrings/docker.gpg
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
                > /etc/apt/sources.list.d/docker.list

              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              systemctl enable docker
              systemctl start docker

              mkdir -p /opt/monitoring
              cat >/opt/monitoring/docker-compose.yml <<'YAML'
              services:
                prometheus:
                  image: prom/prometheus:latest
                  container_name: prometheus
                  restart: unless-stopped
                  ports:
                    - "9090:9090"
                  volumes:
                    - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
                    - prometheus_data:/prometheus

                grafana:
                  image: grafana/grafana:latest
                  container_name: grafana
                  restart: unless-stopped
                  ports:
                    - "3000:3000"
                  volumes:
                    - grafana_data:/var/lib/grafana

              volumes:
                prometheus_data: {}
                grafana_data: {}
              YAML

              cat >/opt/monitoring/prometheus.yml <<'YAML'
              global:
                scrape_interval: 15s

              scrape_configs:
                - job_name: "prometheus"
                  static_configs:
                    - targets: ["localhost:9090"]
              YAML

              cd /opt/monitoring
              docker compose up -d
              EOF

  tags = {
    Name        = "${local.name}-monitoring"
    Environment = var.environment
    Project     = var.project
  }
}
