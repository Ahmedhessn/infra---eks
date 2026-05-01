## WHY: Most production architectures are multi-AZ to survive a single AZ outage.
## WHAT: We select the first `var.az_count` AZs in the region and build public/private subnets across them.
## HOW: Use `aws_availability_zones` data source, then slice to a stable subset.

data "aws_availability_zones" "available" {
  ## WHAT: All AZs that are currently available in the selected AWS region.
  state = "available"
}

locals {
  ## HOW: Use only the first N AZs so subnet creation is deterministic.
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  eks_enabled = var.eks_cluster_name != null && trimspace(var.eks_cluster_name) != ""

  eks_cluster_tags = local.eks_enabled ? {
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  } : {}

  eks_public_subnet_tags  = local.eks_enabled ? merge(local.eks_cluster_tags, { "kubernetes.io/role/elb" = "1" }) : {}
  eks_private_subnet_tags = local.eks_enabled ? merge(local.eks_cluster_tags, { "kubernetes.io/role/internal-elb" = "1" }) : {}

  ## WHY: Karpenter discovers subnets/security-groups via a shared cluster discovery tag.
  ## WHAT: When EKS is enabled, add the standard discovery tag to all subnets.
  karpenter_discovery_tags = local.eks_enabled ? {
    "karpenter.sh/discovery" = var.eks_cluster_name
  } : {}
}

resource "aws_vpc" "this" {
  ## WHY: A VPC isolates networking for the cluster and lets us control routing, security, and IP space.
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.name
  }
}

resource "aws_internet_gateway" "this" {
  ## WHY: Public subnets need an Internet Gateway to reach the internet directly.
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name}-igw"
  }
}

resource "aws_subnet" "public" {
  ## WHY: Public subnet holds NAT Gateway (and optionally public-facing resources).
  ## HOW: `map_public_ip_on_launch=true` gives instances a public IP if you ever place them here.
  for_each = { for idx, az in local.azs : idx => az }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value
  ## HOW: Derive subnets from VPC CIDR. Newbits=8 is simple; adjust if you need different sizing.
  cidr_block              = cidrsubnet(var.cidr_block, 8, each.key)
  map_public_ip_on_launch = true

  tags = merge(
    { Name = "${var.name}-public-${each.value}" },
    local.eks_public_subnet_tags,
    local.karpenter_discovery_tags
  )
}

resource "aws_subnet" "private" {
  ## WHY: Private subnets host the Kubernetes nodes without direct public exposure.
  for_each = { for idx, az in local.azs : idx => az }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value
  ## HOW: Use a different subnet index range (+10) to avoid overlap with public subnets.
  cidr_block = cidrsubnet(var.cidr_block, 8, each.key + 10)

  tags = merge(
    { Name = "${var.name}-private-${each.value}" },
    local.eks_private_subnet_tags,
    local.karpenter_discovery_tags
  )
}

resource "aws_eip" "nat" {
  ## WHY: NAT Gateway needs a stable public IP (Elastic IP) to reach the internet from private subnets.
  domain = "vpc"
  tags = {
    Name = "${var.name}-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  ## WHY: Instances in private subnets still need outbound internet (apt updates, container pulls, etc).
  ## HOW: NAT lives in a public subnet and provides outbound internet for private subnets.
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id
  depends_on    = [aws_internet_gateway.this]

  tags = {
    Name = "${var.name}-nat"
  }
}

resource "aws_route_table" "public" {
  ## WHY: Public subnet route table sends 0.0.0.0/0 to the Internet Gateway.
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  ## WHAT: Default route for public subnets to the Internet Gateway.
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  ## HOW: Attach each public subnet to the public route table.
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  ## WHY: Private subnet route table sends 0.0.0.0/0 to the NAT Gateway (not directly to IGW).
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name}-private-rt"
  }
}

resource "aws_route" "private_nat" {
  ## WHAT: Default route for private subnets to the NAT Gateway.
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private" {
  ## HOW: Attach each private subnet to the private route table.
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

