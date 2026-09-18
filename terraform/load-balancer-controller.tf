resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = var.ALB_name
    namespace = "kube-system"
  }

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    time_sleep.terraform_admin_propagation,
  ]
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = var.ALB_name
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "3.5.0"

  set = [
    {
      name  = "clusterName"
      value = aws_eks_cluster.main.name
    },
    {
      name  = "vpcId"
      value = aws_vpc.main.id
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
    },
  ]

  depends_on = [
    aws_eks_pod_identity_association.aws_load_balancer_controller,
    kubernetes_service_account.aws_load_balancer_controller,
    aws_eks_node_group.main,
    time_sleep.terraform_admin_propagation,
  ]
}

### Replaces ingress ###

resource "kubectl_manifest" "meridian_tgb" {
  yaml_body = yamlencode({
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"
    metadata = {
      name      = "${var.application_service_name}-tgb"
      namespace = "default"
    }
    spec = {
      serviceRef = {
        name = var.application_service_name
        port = 80
      }
      targetGroupARN = aws_lb_target_group.meridian.arn
      targetType     = "ip"
    }
  })

  depends_on = [
    helm_release.aws_load_balancer_controller,
    aws_lb_target_group.meridian,
    time_sleep.terraform_admin_propagation,
  ]
}
