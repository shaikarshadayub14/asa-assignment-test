resource "kubernetes_deployment" "app" {
  metadata {
    name      = "vulntracker-api"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "vulntracker-api"
    }
  }

  spec {
    replicas = var.replica_count

    selector {
      match_labels = {
        app = "vulntracker-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "vulntracker-api"
        }
      }

      spec {
        automount_service_account_token = false

        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          run_as_group    = 1000
          fs_group        = 1000
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "vulntracker-api"
          image = var.image

          port {
            container_port = 8000
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.app.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          # read_only_root_filesystem is intentionally not enabled: the app falls
          # back to a local SQLite file under /app when DATABASE_URL points at
          # sqlite. A real production DATABASE_URL (e.g. RDS/Cloud SQL) would
          # remove this constraint entirely.
          security_context {
            run_as_non_root            = true
            run_as_user                = 1000
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 10
            period_seconds        = 15
          }
        }
      }
    }
  }
}
