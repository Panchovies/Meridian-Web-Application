### VPC ###

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
    # Required by the EKS/ALB controllers to discover this VPC for the cluster.
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

### Public subnets (2 AZs) ###

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                         = "${var.project_name}-public-${var.availability_zones[count.index]}"
    "kubernetes.io/cluster/${var.cluster_name}"  = "shared"
    "kubernetes.io/role/elb"                     = "1"
  }
}
