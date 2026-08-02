resource "kubernetes_network_policy" "app_ingress" {
  metadata {
    name      = "vulntracker-api-ingress"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "vulntracker-api"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Only allow inbound traffic from pods in the ingress-controller namespace,
    # on the app's port. Nothing else in the cluster can reach this pod directly.
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "ingress-nginx"
          }
        }
      }

      ports {
        port     = 8000
        protocol = "TCP"
      }
    }

    # Allow DNS resolution and outbound calls to the notify service.
    egress {
      to {
        namespace_selector {}
      }

      ports {
        port     = 53
        protocol = "UDP"
      }
      ports {
        port     = 53
        protocol = "TCP"
      }
    }

    egress {
      ports {
        port     = 3001
        protocol = "TCP"
      }
    }
  }
}
