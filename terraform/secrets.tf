### Finds the secret in AWS Secrets Manager ###
data "aws_secretsmanager_secret" "meridian_api_keys" {
  name = "meridian-api-keys"
}

### Gets the helm release for the External Secrets Add-On ###
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

### Modify manifest to configure AWS Secrets Manager ###
resource "kubectl_manifest" "aws_secrets_manager" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"

    metadata = {
      name      = "aws-secrets-manager"
      namespace = "default"
    }

    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
        }
      }
    }
  })

  depends_on = [
    aws_eks_pod_identity_association.external_secrets
  ]
}

### Synchronie the secret from AWS Secrets Manager to Kubernetes Secret ###
resource "kubectl_manifest" "meridian_api_keys" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"

    metadata = {
      name      = "meridian-api-keys"
      namespace = "default"
    }

    spec = {
      refreshInterval = "1h"

      secretStoreRef = {
        name = "aws-secrets-manager"
        kind = "SecretStore"
      }

      target = {
        name = "meridian-api-keys"
      }

      data = [
        {
          secretKey = "NEWS_API_KEY"

          remoteRef = {
            key      = "meridian-api-keys"
            property = "NEWS_API_KEY"
          }
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.aws_secrets_manager
  ]
}
