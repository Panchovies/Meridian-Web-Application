### Creates ALB Ingress for the application service ###
resource "kubernetes_ingress_v1" "meridian" {
  metadata {
    name      = "${var.application_service_name}-ingress"
    namespace = "default"

    annotations = {
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"

      "alb.ingress.kubernetes.io/target-type" = "ip"

      "alb.ingress.kubernetes.io/listen-ports" = jsonencode([
        {
          HTTP = 80
        }
      ])

      "alb.ingress.kubernetes.io/healthcheck-path" = "/health"

      "alb.ingress.kubernetes.io/healthcheck-port" = "traffic-port"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = var.application_service_name

              port {
                number = 5000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.aws_load_balancer_controller
  ]
}