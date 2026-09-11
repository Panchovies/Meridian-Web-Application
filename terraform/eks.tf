
### CloudWatch  Log Group for EKS ###
resource "aws_cloudwatch_log_group" "eks_cluster" {
  # The name must exactly match the format EKS expects
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7
}

### EKS cluster ###
### Depends on vpc being up and running ###

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  vpc_config {
    subnet_ids = concat(
      aws_subnet.public[*].id,
      aws_subnet.private[*].id,
    )
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator",
  "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_cloudwatch_log_group.eks_cluster,
  ]
}

### EKS access entry for GitLab CI user ###
resource "aws_eks_access_entry" "ci" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::163558211438:user/GitLab-CI"
}

resource "aws_eks_access_policy_association" "ci_edit_default_namespace" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::163558211438:user/GitLab-CI"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.ci]
}

### Managed node group ###

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${aws_eks_cluster.main.name}-workers"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = aws_subnet.private[*].id

  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly,
    aws_iam_role_policy_attachment.cloudwatch_agent,
    aws_nat_gateway.main,
    aws_route_table_association.private,
  ]
}
