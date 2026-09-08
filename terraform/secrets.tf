### Finds the secret in AWS Secrets Manager ###
data "aws_secretsmanager_secret" "meridian_api_keys" {
  name = "meridian-api-keys"
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"

  values = [
    yamlencode({
      serviceAccount = {
        create = true
        name   = "external-secrets"
      }
    })
  ]

  depends_on = [
    aws_eks_addon.pod_identity_agent
  ]
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "external-secrets"
  service_account = "external-secrets"

  role_arn = aws_iam_role.external_secrets.arn

  depends_on = [
    helm_release.external_secrets,
    aws_iam_role_policy_attachment.external_secrets
  ]
}