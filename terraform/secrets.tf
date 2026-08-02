data "aws_secretsmanager_secret" "app" {
  name = var.secrets_manager_secret_name
}

data "aws_secretsmanager_secret_version" "app" {
  secret_id = data.aws_secretsmanager_secret.app.id
}

locals {
  app_secret_values = jsondecode(data.aws_secretsmanager_secret_version.app.secret_string)
}

resource "kubernetes_secret" "app" {
  metadata {
    name      = "vulntracker-app-secrets"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    SECRET_KEY         = local.app_secret_values.SECRET_KEY
    DATABASE_URL       = local.app_secret_values.DATABASE_URL
    DB_USER            = local.app_secret_values.DB_USER
    DB_PASSWORD        = local.app_secret_values.DB_PASSWORD
    ADMIN_API_KEY      = local.app_secret_values.ADMIN_API_KEY
    NOTIFY_SERVICE_URL = local.app_secret_values.NOTIFY_SERVICE_URL
  }

  type = "Opaque"
}
