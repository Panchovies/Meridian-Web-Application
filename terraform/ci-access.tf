locals {
  gitlab_ci_principal_arn       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.gitlab_ci_user_name}"
  terraform_admin_principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.admin_user_name}"
}

resource "aws_eks_access_entry" "terraform_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = local.terraform_admin_principal_arn
}

resource "aws_eks_access_policy_association" "terraform_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = local.terraform_admin_principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.terraform_admin]
}

resource "aws_eks_access_entry" "gitlab_ci" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = local.gitlab_ci_principal_arn
}

resource "aws_eks_access_policy_association" "gitlab_ci_cluster_edit" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = local.gitlab_ci_principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.gitlab_ci]
}
