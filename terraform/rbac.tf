resource "kubectl_manifest" "gitlab_ci_custom_resources_role" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "Role"

    metadata = {
      name      = "gitlab-ci-custom-resources"
      namespace = "default"
    }

    rules = [
      {
        apiGroups = ["elbv2.k8s.aws"]
        resources = ["targetgroupbindings"]
        verbs = [
          "get",
          "list",
          "watch",
          "create",
          "update",
          "patch",
          "delete"
        ]
      },
      {
        apiGroups = ["external-secrets.io"]
        resources = ["secretstores"]
        verbs = [
          "get",
          "list",
          "watch",
          "create",
          "update",
          "patch",
          "delete"
        ]
      }
    ]
  })

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.external_secrets
  ]
}

resource "kubectl_manifest" "gitlab_ci_custom_resources_rolebinding" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "RoleBinding"

    metadata = {
      name      = "gitlab-ci-custom-resources"
      namespace = "default"
    }

    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "Role"
      name     = "gitlab-ci-custom-resources"
    }

    subjects = [
      {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "Group"
        name     = "gitlab-ci"
      }
    ]
  })

  depends_on = [
    kubectl_manifest.gitlab_ci_custom_resources_role,
    aws_eks_access_entry.gitlab_ci
  ]
}
