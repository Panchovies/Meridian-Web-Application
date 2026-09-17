### Creates the service that allows the platform api status to get credentials ###
resource "kubernetes_service_account" "meridian_app_status" {
  metadata {
    name      = "meridian-web-application"
    namespace = "default"
  }
}
