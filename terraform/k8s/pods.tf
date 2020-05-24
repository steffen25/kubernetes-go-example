resource "kubernetes_deployment" "go-api" {
  metadata {
    name = "go-api"
    labels = {
      app = "go-api"
      tier = "backend"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "go-api"
        tier = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "go-api"
          tier = "backend"
        }
      }

      spec {
        container {
          image = "eu.gcr.io/go-kubernetes-test-275611/go-api:v4"
          name  = "go-api"

          resources {
            limits {
              cpu    = "200m"
              memory = "256Mi"
            }
            requests {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/ping"
              port = 8080

              http_header {
                name  = "X-Custom-Header"
                value = "Awesome"
              }
            }

            initial_delay_seconds = 3
            period_seconds        = 3
          }

          port {
              container_port = 8080
              name = "go-api"
          }
        }
      }
    }
  }
}