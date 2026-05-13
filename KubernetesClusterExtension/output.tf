###############################################################
# MODULE: KubernetesClusterExtension - Outputs
###############################################################

output "id" {
  description = "Resource ID of the cluster extension."
  value       = azurerm_kubernetes_cluster_extension.this.id
}

output "name" {
  description = "Extension name on the cluster."
  value       = azurerm_kubernetes_cluster_extension.this.name
}

output "current_version" {
  description = "Currently installed extension version (read after apply)."
  value       = azurerm_kubernetes_cluster_extension.this.current_version
}
