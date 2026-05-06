output "namespace_name" {
  value = kubernetes_namespace_v1.medicine_namespace.metadata[0].name
}