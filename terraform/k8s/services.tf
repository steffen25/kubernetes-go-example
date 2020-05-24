resource "kubernetes_service" "go-api-service" {
  metadata {
    name = "go-api-service"
  }
  spec {
    selector = {
      app = "go-api"
    }
    session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}

# resource "kubernetes_pod" "go_api" {
#   metadata {
#     name = "go-api-app"
#     labels = {
#       app = "go-api-nginx"
#     }
#   }

#   spec {
#     container {
#       image = "nginx:1.17.10"
#       name  = "go-api-nginx"
#     }
#   }
# }