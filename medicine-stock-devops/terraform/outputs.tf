output "namespace_name" {
  description = "Kubernetes namespace name"
  value       = kubernetes_namespace_v1.medicine_namespace.metadata[0].name
}

output "service_account_name" {
  description = "ServiceAccount name"
  value       = kubernetes_service_account_v1.medicine_stock.metadata[0].name
}

output "config_map_name" {
  description = "ConfigMap name"
  value       = kubernetes_config_map_v1.app_config.metadata[0].name
}

output "secret_name" {
  description = "Secret name"
  value       = kubernetes_secret_v1.app_secrets.metadata[0].name
  sensitive   = true
}

output "role_name" {
  description = "Role name"
  value       = kubernetes_role_v1.medicine_stock.metadata[0].name
}

output "deployment_info" {
  description = "Deployment information"
  value = {
    namespace = kubernetes_namespace_v1.medicine_namespace.metadata[0].name
    service_account = kubernetes_service_account_v1.medicine_stock.metadata[0].name
    config_map = kubernetes_config_map_v1.app_config.metadata[0].name
    labels = {
      app = "medicine-stock"
    }
  }
}