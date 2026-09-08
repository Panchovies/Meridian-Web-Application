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