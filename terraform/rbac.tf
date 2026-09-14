# rbac.tf

# -------------------------------------------------------------------
# kube-system: GitLab CI can read the ALB controller ServiceAccount
# and the RBAC objects Terraform keeps in state.
# -------------------------------------------------------------------

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
        apiGroups     = [""]
        resources     = ["serviceaccounts"]
        resourceNames = ["aws-load-balancer-controller"]
        verbs         = ["get"]
      },
      {
        apiGroups = [""]
        resources = ["secrets"]
        verbs     = ["get", "list"]
      },
      {
        apiGroups     = ["rbac.authorization.k8s.io"]
        resources     = ["roles"]
        resourceNames = ["gitlab-ci-alb-service-account"]
        verbs         = ["get"]
      },
      {
        apiGroups     = ["rbac.authorization.k8s.io"]
        resources     = ["rolebindings"]
        resourceNames = ["gitlab-ci-alb-service-account"]
        verbs         = ["get"]
      }
    ]
  })
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
        kind     = "Group"
        name     = "gitlab-ci"
        apiGroup = "rbac.authorization.k8s.io"
      }
    ]
  })
}


# -------------------------------------------------------------------
# external-secrets namespace: GitLab CI can read the namespace itself.
# -------------------------------------------------------------------

resource "kubectl_manifest" "gitlab_ci_namespace_role" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRole"

    metadata = {
      name = "gitlab-ci-external-secrets-namespace"
    }

    rules = [
      {
        apiGroups     = [""]
        resources     = ["namespaces"]
        resourceNames = ["external-secrets"]
        verbs         = ["get"]
      },
      {
        apiGroups     = ["rbac.authorization.k8s.io"]
        resources     = ["clusterroles"]
        resourceNames = ["gitlab-ci-external-secrets-namespace"]
        verbs         = ["get"]
      },
      {
        apiGroups     = ["rbac.authorization.k8s.io"]
        resources     = ["clusterrolebindings"]
        resourceNames = ["gitlab-ci-external-secrets-namespace"]
        verbs         = ["get"]
      }
    ]
  })
}

resource "kubectl_manifest" "gitlab_ci_namespace_rolebinding" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"

    metadata = {
      name = "gitlab-ci-external-secrets-namespace"
    }

    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "gitlab-ci-external-secrets-namespace"
    }

    subjects = [
      {
        kind     = "Group"
        name     = "gitlab-ci"
        apiGroup = "rbac.authorization.k8s.io"
      }
    ]
  })
}


# -------------------------------------------------------------------
# external-secrets namespace: GitLab CI can read the External Secrets
# ServiceAccount.
# -------------------------------------------------------------------

resource "kubectl_manifest" "gitlab_ci_external_secrets_service_account_role" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "Role"

    metadata = {
      name      = "gitlab-ci-external-secrets-service-account"
      namespace = "external-secrets"
    }

    rules = [
      {
        apiGroups     = [""]
        resources     = ["serviceaccounts"]
        resourceNames = ["external-secrets"]
        verbs         = ["get"]
      },
      {
        apiGroups = [""]
        resources = ["secrets"]
        verbs     = ["get"]
      },
      {
        apiGroups     = ["rbac.authorization.k8s.io"]
        resources     = ["roles"]
        resourceNames = ["gitlab-ci-external-secrets-service-account"]
        verbs         = ["get"]
      },
      {
        apiGroups     = ["rbac.authorization.k8s.io"]
        resources     = ["rolebindings"]
        resourceNames = ["gitlab-ci-external-secrets-service-account"]
        verbs         = ["get"]
      }
    ]
  })
}

resource "kubectl_manifest" "gitlab_ci_external_secrets_service_account_rolebinding" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "RoleBinding"

    metadata = {
      name      = "gitlab-ci-external-secrets-service-account"
      namespace = "external-secrets"
    }

    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "Role"
      name     = "gitlab-ci-external-secrets-service-account"
    }

    subjects = [
      {
        kind     = "Group"
        name     = "gitlab-ci"
        apiGroup = "rbac.authorization.k8s.io"
      }
    ]
  })
}


# -------------------------------------------------------------------
# default: GitLab CI can read the two CRDs that are in Terraform state.
# -------------------------------------------------------------------

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
        verbs     = ["get"]
      },
      {
        apiGroups = ["external-secrets.io"]
        resources = ["secretstores", "externalsecrets"]
        verbs     = ["get"]
      },
      {
        apiGroups     = ["rbac.authorization.k8s.io"]
        resources     = ["roles"]
        resourceNames = ["gitlab-ci-custom-resources"]
        verbs         = ["get"]
      },
      {
        apiGroups     = ["rbac.authorization.k8s.io"]
        resources     = ["rolebindings"]
        resourceNames = ["gitlab-ci-custom-resources"]
        verbs         = ["get"]
      }
    ]
  })
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
        kind     = "Group"
        name     = "gitlab-ci"
        apiGroup = "rbac.authorization.k8s.io"
      }
    ]
  })
}
