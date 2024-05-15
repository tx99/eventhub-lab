output "aks_cluster_name" {
  value       = azurerm_kubernetes_cluster.aks_cluster.name
  description = "The name of the AKS cluster"
}

output "aks_cluster_resource_group_name" {
  value       = azurerm_kubernetes_cluster.aks_cluster.resource_group_name
  description = "The resource group name of the AKS cluster"
}

output "aks_cluster_kube_config" {
  value       = azurerm_kubernetes_cluster.aks_cluster.kube_config_raw
  description = "The raw kubeconfig for the AKS cluster"
  sensitive   = true
}

output "aks_cluster_id" {
  value       = azurerm_kubernetes_cluster.aks_cluster.id
  description = "The ID of the AKS cluster"
}

output "aks_cluster_fqdn" {
  value       = azurerm_kubernetes_cluster.aks_cluster.fqdn
  description = "The FQDN of the AKS cluster"
}
