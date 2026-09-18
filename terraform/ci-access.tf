locals {
  gitlab_ci_principal_arn       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.gitlab_ci_user_name}"
  terraform_admin_principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.admin_user_name}"
}

# Admin / Terraform access
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

  depends_on = [
    aws_eks_access_entry.terraform_admin
  ]
}

# Access entries can take a few seconds to propagate to the control plane's
# authorizer. Give it a buffer before anything tries to use this identity's
# permissions to read/write RBAC objects.
resource "time_sleep" "terraform_admin_propagation" {
  create_duration = "30s"

  depends_on = [
    aws_eks_access_policy_association.terraform_admin
  ]
}

# GitLab CI access
resource "aws_eks_access_entry" "gitlab_ci" {
  cluster_name      = aws_eks_cluster.main.name
  principal_arn     = local.gitlab_ci_principal_arn
  kubernetes_groups = ["gitlab-ci"]
}

resource "aws_eks_access_policy_association" "gitlab_ci_edit" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = local.gitlab_ci_principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["default"]
  }

  depends_on = [
    aws_eks_access_entry.gitlab_ci
  ]
}
