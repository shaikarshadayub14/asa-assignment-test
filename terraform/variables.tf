variable "aws_region" {
  description = "AWS region hosting Secrets Manager and the target cluster"
  type        = string
  default     = "us-east-1"
}

variable "kubeconfig_path" {
  description = "Path to a kubeconfig file for the target cluster"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context to use"
  type        = string
  default     = "vulntracker-cluster"
}

variable "namespace" {
  description = "Kubernetes namespace for the VulnTracker API"
  type        = string
  default     = "vulntracker"
}

variable "image" {
  description = "Container image to deploy, including tag"
  type        = string
  default     = "arshadayubshaik/vulntracker-api:latest"
}

variable "replica_count" {
  description = "Number of pod replicas"
  type        = number
  default     = 2
}

variable "secrets_manager_secret_name" {
  description = "Name of the AWS Secrets Manager secret holding app secrets (SECRET_KEY, DATABASE_URL, DB_USER, DB_PASSWORD, ADMIN_API_KEY, NOTIFY_SERVICE_URL)"
  type        = string
  default     = "vulntracker/app-secrets"
}
