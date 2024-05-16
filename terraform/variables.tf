variable "resource_group_name" {
  description = "Resource group name"
  default     = "eventhub-lab"
}

variable "location" {
  description = "Azure region"
  default     = "northeurope"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  default     = "eventhub-aks"
}

variable "kubernetes_version" {
  description = "K8s version"
  default     = "1.29.2"
}

variable "eventhub_namespace_name" {
  description = "Name of the Event Hubs namespace"
  default     = "evthubnamespace825"
}

variable "eventhub_name" {
  description = "Name of the Event Hub"
  default     = "eventhub"
}

variable "key_vault_name" {
  description = "Name of the Key Vault"
  default     = "eventhub-keyvault"
}

variable "app_insights_name" {
  description = "Name of the Application Insights instance"
  default     = "eventhub-app-insights"
}