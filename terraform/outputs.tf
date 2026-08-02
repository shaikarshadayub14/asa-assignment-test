output "namespace" {
  description = "Kubernetes namespace the app was deployed into"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "service_name" {
  description = "In-cluster service name for the VulnTracker API"
  value       = kubernetes_service.app.metadata[0].name
}
