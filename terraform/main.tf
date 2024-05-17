provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "eventhub_resource_group" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_key_vault" "keyvault" {
  name                = "${var.resource_group_name}-kv"
  location            = azurerm_resource_group.eventhub_resource_group.location
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = var.tenant_id
    object_id = azurerm_kubernetes_cluster.aks.kubelet_identity.0.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Set",
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge"
    ]
  }
}

resource "azurerm_eventhub_namespace" "eventhub_namespace" {
  name                = var.eventhub_namespace_name
  location            = azurerm_resource_group.eventhub_resource_group.location
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  sku                 = "Standard"
  capacity            = 2
}

resource "azurerm_key_vault_secret" "eventhub_connection_string" {
  name         = "eventhub-connection-string"
  value        = azurerm_eventhub_namespace.eventhub_namespace.default_primary_connection_string
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.resource_group_name}-aks"
  location            = azurerm_resource_group.eventhub_resource_group.location
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  dns_prefix          = "${var.resource_group_name}-aks"

  default_node_pool {
    name       = var.node_pool_name
    node_count = 1
    vm_size    = var.vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }
}

resource "azurerm_application_insights" "app_insights" {
  name                = "${var.resource_group_name}-ai"
  location            = azurerm_resource_group.eventhub_resource_group.location
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  application_type    = "other"
}
