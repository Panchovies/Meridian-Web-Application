# GitLab can manage the ALB controller ServiceAccount
# in kube-system.
resource "kubectl_manifest" "gitlab_ci_alb_service_account_role" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "Role"

    metadata = {
      name      = "gitlab-ci-alb-service-account"
      namespace = "kube-system"
    }

    rules = [
      {
        apiGroups = [""]
        resources = ["serviceaccounts"]
        resourceNames = [
          "aws-load-balancer-controller"
        ]
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
    helm_release.aws_load_balancer_controller
  ]
}

resource "kubectl_manifest" "gitlab_ci_alb_service_account_rolebinding" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "RoleBinding"

    metadata = {
      name      = "gitlab-ci-alb-service-account"
      namespace = "kube-system"
    }

    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "Role"
      name     = "gitlab-ci-alb-service-account"
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
    kubectl_manifest.gitlab_ci_alb_service_account_role
  ]
}

# GitLab can read/manage the external-secrets Namespace.
# Namespace is cluster-scoped, so this must be a ClusterRole.
resource "kubectl_manifest" "gitlab_ci_namespace_role" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRole"

    metadata = {
      name = "gitlab-ci-namespace"
    }

    rules = [
      {
        apiGroups = [""]
        resources = ["namespaces"]
        resourceNames = [
          "external-secrets"
        ]
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
    helm_release.external_secrets
  ]
}

resource "kubectl_manifest" "gitlab_ci_namespace_rolebinding" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"

    metadata = {
      name = "gitlab-ci-namespace"
    }

    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "gitlab-ci-namespace"
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
    kubectl_manifest.gitlab_ci_namespace_role
  ]
}

# GitLab can manage the two custom resources in default.
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
    kubectl_manifest.gitlab_ci_custom_resources_role
  ]
}
