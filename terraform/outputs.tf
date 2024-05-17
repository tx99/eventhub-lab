output "eventhub_namespace_name" {
  value = azurerm_eventhub_namespace.eventhub_namespace.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "app_insights_instrumentation_key" {
  value = azurerm_application_insights.app_insights.instrumentation_key
  sensitive = true
}

output "key_vault_id" {
  value = azurerm_key_vault.keyvault.id
}
