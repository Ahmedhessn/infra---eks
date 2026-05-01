## WHY: Self-managed K8s on EC2 needs OS images, networking rules, IAM, and bootstrapping (kubeadm).
## WHAT: This module creates 1 master EC2 + N workers EC2, a security group, and minimal IAM.
## HOW: Use Ubuntu 22.04 AMI, install containerd + kubeadm/kubelet/kubectl via cloud-init, then:
## - master runs `kubeadm init` and publishes a join command to SSM Parameter Store
## - workers read the join command from SSM and execute it
##
## NOTE: This is a "managed self" cluster (self-managed Kubernetes, managed by Terraform).

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "k8s" {
  name_prefix = "${var.name}-sg-"
  vpc_id      = var.vpc_id
  description = "Kubernetes cluster security group"

  ingress {
    description = "Kubernetes API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    ## WHY: Exposing 6443 to the world is risky.
    ## HOW: Default to VPC-only access; optionally add extra CIDRs via `allowed_k8s_api_cidrs`.
    cidr_blocks = concat([var.vpc_cidr], var.allowed_k8s_api_cidrs)
  }

  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      ## WHY: SSH should be restricted; default is disabled (empty list).
      ## HOW: Only open if you explicitly provide CIDRs.
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  ingress {
    description = "Node-to-node all traffic within SG"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "node" {
  ## IAM name_prefix has a strict max length (38). Keep it short but identifiable.
  ## We derive a safe prefix from the cluster name to avoid apply-time failures.
  name_prefix        = "${local.iam_name_prefix}-node-"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  ## WHY: Least-privilege needs a precise ARN for the one SSM Parameter we use.
  ## HOW: Parameter ARNs are `...:parameter/<name>` (note no extra slash before the name).
  ## NOTE: `data.aws_region.current.name` is deprecated in newer AWS providers; `id` is the region name.
  join_param_arn = "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter${var.join_parameter_name}"
}

data "aws_iam_policy_document" "node_min" {
  statement {
    sid    = "EcrRead"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    ## WHY: `GetAuthorizationToken` must be `*` in AWS; the others can be scoped but typically are ok.
    resources = ["*"]
  }

  statement {
    sid    = "SsmCore"
    effect = "Allow"
    actions = [
      "ssm:UpdateInstanceInformation",
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "JoinParamReadWrite"
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:DeleteParameter"
    ]
    ## WHY: Workers need to read the join command; master needs to write it.
    ## HOW: Scope to exactly one parameter per cluster/environment.
    resources = [local.join_param_arn]
  }
}

resource "aws_iam_policy" "node_min" {
  name_prefix = "${local.iam_name_prefix}-node-min-"
  policy      = data.aws_iam_policy_document.node_min.json
}

resource "aws_iam_role_policy_attachment" "node_min" {
  role       = aws_iam_role.node.name
  policy_arn = aws_iam_policy.node_min.arn
}

resource "aws_iam_instance_profile" "node" {
  name_prefix = "${local.iam_name_prefix}-node-"
  role        = aws_iam_role.node.name
}

locals {
  ## WHY: We keep bootstrap logic in user-data to avoid manual setup.
  ## WHAT: Install fragment is a separate .tftpl so bash heredocs end with terminators at column 0.
  ## HOW: If this lived inside a Terraform <<-EOF string, indented closing lines break nested <<SYSCTL.
  k8s_major_minor = join(".", slice(split(".", var.kubernetes_version), 0, 2))
  k8s_full        = var.kubernetes_version
  install_script = templatefile("${path.module}/install_bootstrap.sh.tftpl", {
    K8S_MAJOR_MINOR = local.k8s_major_minor
    K8S_FULL        = local.k8s_full
  })

  ## WHY: AWS IAM `name_prefix` max length is 38 characters.
  ## HOW: Truncate the cluster name so `${prefix}-node-` stays valid.
  iam_name_prefix = substr(replace(var.name, "_", "-"), 0, 28)
}

resource "terraform_data" "master_recreate" {
  input = {
    instance_type = var.instance_type_master
    market_type   = var.master_market_type
  }
}

resource "aws_instance" "master" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type_master
  ## WHY: Keep master private (no public IP). Access via SSM or via a bastion/VPN if needed.
  subnet_id                   = var.subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.k8s.id]
  iam_instance_profile        = aws_iam_instance_profile.node.name
  key_name                    = var.ssh_key_name
  associate_public_ip_address = false
  ## WHY: Spot one-time instances cannot be stopped/started. Changing user_data must replace the instance.
  ## HOW: Force replacement on user_data changes (works for on-demand too; it is just more disruptive).
  user_data_replace_on_change = true

  dynamic "instance_market_options" {
    for_each = var.master_market_type == "spot" ? [1] : []
    content {
      market_type = "spot"

      spot_options {
        instance_interruption_behavior = "terminate"
      }
    }
  }

  user_data = templatefile("${path.module}/user_data_master.sh.tftpl", {
    K8S_MAJOR_MINOR = local.k8s_major_minor
    K8S_FULL        = local.k8s_full
    INSTALL_SCRIPT  = local.install_script
    JOIN_PARAMETER  = var.join_parameter_name
  })

  tags = {
    Name = "${var.name}-master"
    Role = "master"
  }

  lifecycle {
    ## WHY: Avoid two concurrent control-plane nodes during replacement (etcd/API conflicts risk).
    ## HOW: Use the default destroy-then-create ordering (omit create_before_destroy / set false).
    replace_triggered_by = [terraform_data.master_recreate]
  }
}

resource "aws_instance" "worker" {
  count         = var.worker_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type_worker
  ## HOW: Spread workers across provided subnets (usually private) for multi-AZ resilience.
  subnet_id                   = element(var.subnet_ids, count.index % length(var.subnet_ids))
  vpc_security_group_ids      = [aws_security_group.k8s.id]
  iam_instance_profile        = aws_iam_instance_profile.node.name
  key_name                    = var.ssh_key_name
  associate_public_ip_address = false
  ## WHY: Spot one-time instances cannot be stopped/started. Changing user_data must replace the instance.
  user_data_replace_on_change = true

  dynamic "instance_market_options" {
    for_each = var.worker_market_type == "spot" ? [1] : []
    content {
      market_type = "spot"

      spot_options {
        instance_interruption_behavior = "terminate"
      }
    }
  }

  user_data = templatefile("${path.module}/user_data_worker.sh.tftpl", {
    K8S_MAJOR_MINOR = local.k8s_major_minor
    K8S_FULL        = local.k8s_full
    INSTALL_SCRIPT  = local.install_script
    JOIN_PARAMETER  = var.join_parameter_name
  })

  tags = {
    Name = "${var.name}-worker-${count.index + 1}"
    Role = "worker"
  }
}

