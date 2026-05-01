## =========================
## Karpenter prerequisites
## =========================
## WHY: Enable on-demand node provisioning based on unschedulable pods.
## NOTE: This stack creates AWS-side prerequisites only (IAM + SQS + tags).
##       Installing the Karpenter Helm chart + applying NodePool/EC2NodeClass
##       is done via kubectl/helm after `terraform apply`.

locals {
  ## WHY: Many AWS resources enforce short name limits (e.g., EventBridge rule name <= 64).
  ## HOW: Derive short deterministic prefixes from the (potentially long) cluster name.
  karpenter_hash       = substr(md5(module.eks.cluster_name), 0, 6)
  karpenter_short      = "${substr(replace(module.eks.cluster_name, "_", "-"), 0, 24)}-${local.karpenter_hash}"
  karpenter_event_base = "${local.karpenter_short}-karp"
}

## Tag the EKS cluster security group for discovery-based selection.
resource "aws_ec2_tag" "karpenter_cluster_sg_discovery" {
  resource_id = module.eks.cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = module.eks.cluster_name
}

## -------------------------
## SQS queue for interruptions
## -------------------------
resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${local.karpenter_event_base}-interrupt"
  message_retention_seconds = 300
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeSendMessage"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter_interruption.arn
      },
    ]
  })
}

resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  name        = "${local.karpenter_event_base}-spot-int"
  description = "EC2 Spot interruption warnings to Karpenter."

  event_pattern = jsonencode({
    source        = ["aws.ec2"]
    "detail-type" = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  rule      = aws_cloudwatch_event_rule.karpenter_spot_interruption.name
  target_id = "karpenter-sqs"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_rebalance" {
  name        = "${local.karpenter_event_base}-rebalance"
  description = "EC2 rebalance recommendations to Karpenter."

  event_pattern = jsonencode({
    source        = ["aws.ec2"]
    "detail-type" = ["EC2 Instance Rebalance Recommendation"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_rebalance" {
  rule      = aws_cloudwatch_event_rule.karpenter_rebalance.name
  target_id = "karpenter-sqs"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_instance_state_change" {
  name        = "${local.karpenter_event_base}-state-change"
  description = "EC2 instance state changes to Karpenter."

  event_pattern = jsonencode({
    source        = ["aws.ec2"]
    "detail-type" = ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state_change" {
  rule      = aws_cloudwatch_event_rule.karpenter_instance_state_change.name
  target_id = "karpenter-sqs"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

## -------------------------
## IAM: Node role + instance profile
## -------------------------
data "aws_iam_policy_document" "karpenter_node_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "karpenter_node" {
  ## NOTE: IAM role name_prefix must be <= 38 chars.
  name_prefix        = "${substr(replace(module.eks.cluster_name, "_", "-"), 0, 27)}-karp-node-"
  assume_role_policy = data.aws_iam_policy_document.karpenter_node_assume.json

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "karpenter_node" {
  name_prefix = "${substr(replace(module.eks.cluster_name, "_", "-"), 0, 27)}-karp-node-"
  role        = aws_iam_role.karpenter_node.name
}

## -------------------------
## IAM: Controller IRSA role + policy
## -------------------------
data "aws_iam_policy_document" "karpenter_controller_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }
  }
}

resource "aws_iam_role" "karpenter_controller" {
  ## NOTE: IAM role name_prefix must be <= 38 chars.
  name_prefix        = "${substr(replace(module.eks.cluster_name, "_", "-"), 0, 27)}-karp-ctrl-"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume.json

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

data "aws_iam_policy_document" "karpenter_controller" {
  statement {
    sid     = "KarpenterControllerEKS"
    effect  = "Allow"
    actions = ["eks:DescribeCluster"]
    resources = [
      module.eks.cluster_arn,
    ]
  }

  statement {
    sid    = "KarpenterControllerInstanceProfiles"
    effect = "Allow"
    actions = [
      ## Needed by instanceprofile.garbagecollection controller.
      "iam:ListInstanceProfiles",
      ## Needed when managing/reconciling an instance profile.
      "iam:GetInstanceProfile",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KarpenterControllerEC2"
    effect = "Allow"
    actions = [
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateTags",
      "ec2:DeleteLaunchTemplate",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstances",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "ec2:DescribeVolumes",
      "ec2:DescribeVpcs",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "KarpenterControllerSSM"
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:*:*:parameter/aws/service/*"]
  }

  statement {
    sid       = "KarpenterControllerPricing"
    effect    = "Allow"
    actions   = ["pricing:GetProducts"]
    resources = ["*"]
  }

  statement {
    sid       = "KarpenterControllerPassRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.karpenter_node.arn]
  }

  statement {
    sid    = "KarpenterControllerInterruptionQueue"
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]
    resources = [aws_sqs_queue.karpenter_interruption.arn]
  }
}

resource "aws_iam_policy" "karpenter_controller" {
  name_prefix = "${substr(replace(module.eks.cluster_name, "_", "-"), 0, 27)}-karp-ctrl-"
  policy      = data.aws_iam_policy_document.karpenter_controller.json
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

output "karpenter" {
  description = "Karpenter AWS-side prerequisites for Helm install and NodePool/EC2NodeClass."
  value = {
    cluster_name              = module.eks.cluster_name
    cluster_endpoint          = module.eks.cluster_endpoint
    interruption_queue_name   = aws_sqs_queue.karpenter_interruption.name
    interruption_queue_arn    = aws_sqs_queue.karpenter_interruption.arn
    controller_role_arn       = aws_iam_role.karpenter_controller.arn
    node_instance_profile_arn = aws_iam_instance_profile.karpenter_node.arn
    node_role_arn             = aws_iam_role.karpenter_node.arn
  }
}

