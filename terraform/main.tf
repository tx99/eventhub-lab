terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.107.0" 
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "eventhub_resource_group" {
  name     = var.resource_group_name
  location = var.location
}

# Key Vault
resource "azurerm_key_vault" "keyvault" {
  name                = "${var.resource_group_name}-kv"
  location            = azurerm_resource_group.eventhub_resource_group.location
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

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

# EventHub Namespace
resource "azurerm_eventhub_namespace" "eventhub_namespace" {
  name                = var.eventhub_namespace_name
  location            = azurerm_resource_group.eventhub_resource_group.location
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  sku                 = "Standard"
  capacity            = 2
}

# EventHub Connection String Secret
resource "azurerm_key_vault_secret" "eventhub_connection_string" {
  name         = "eventhub-connection-string"
  value        = azurerm_eventhub_namespace.eventhub_namespace.default_primary_connection_string
  key_vault_id = azurerm_key_vault.keyvault.id
}

# AKS Cluster
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

# Application Insights
resource "azurerm_application_insights" "app_insights" {
  name                = "${var.resource_group_name}-ai"
  location            = azurerm_resource_group.eventhub_resource_group.location
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  application_type    = "other"
}

# Generate a random password for the PostgreSQL admin account
resource "random_password" "postgresql_admin_password" {
  length           = 16
  special          = true
  override_special = "_%+="
}

# Azure Database for PostgreSQL - Single Server
resource "azurerm_postgresql_server" "booksdb" {
  name                     = "${var.resource_group_name}-postgresql"
  resource_group_name      = azurerm_resource_group.eventhub_resource_group.name
  location                 = azurerm_resource_group.eventhub_resource_group.location
  version                  = "11"
  administrator_login      = "psqladminun"
  administrator_login_password = random_password.postgresql_admin_password.result
  sku_name                 = "B_Gen5_1"
  storage_mb               = 5120
  ssl_enforcement_enabled  = true  # Adjust according to your security requirements

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = false
}

# PostgreSQL Database
resource "azurerm_postgresql_database" "booksdb" {
  name                = "booksdb"
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  server_name         = azurerm_postgresql_server.booksdb.name
  charset             = "UTF8"
  collation           = "en_US.utf8"
}


# Store the PostgreSQL admin username and password in Key Vault
resource "azurerm_key_vault_secret" "postgresql_admin_username" {
  name         = "postgresql-admin-username"
  value        = "psqladminun"
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault_secret" "postgresql_admin_password" {
  name         = "postgresql-admin-password"
  value        = random_password.postgresql_admin_password.result
  key_vault_id = azurerm_key_vault.keyvault.id
}

locals {
  postgresql_connection_string = "Host=${azurerm_postgresql_server.booksdb.fqdn};Database=booksdb;Username=${azurerm_postgresql_server.booksdb.administrator_login}@${azurerm_postgresql_server.booksdb.name};Password=${random_password.postgresql_admin_password.result};Port=5432;"
}



resource "azurerm_key_vault_secret" "postgresql_connection_string" {
  name         = "postgresql-connection-string"
  value        = local.postgresql_connection_string
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_kubernetes_cluster_extension" "flux" {
  name                  = "flux"
  cluster_id            = azurerm_kubernetes_cluster.aks.id
  extension_type        = "microsoft.flux"
}

resource "azurerm_kubernetes_flux_configuration" "k8s_flux" {
  name       = "flux-system"
  cluster_id = azurerm_kubernetes_cluster.aks.id
  namespace  = "flux-system"

  git_repository {
    url             = "https://github.com/tx99/eventhub-lab.git"
    reference_type  = "branch"
    reference_value = "master"
  }

  kustomizations {
    name                      = "ingress"
    path                      = "/templates/"
    sync_interval_in_seconds  = 120
    retry_interval_in_seconds = 120
  }

  kustomizations {
    name                      = "frontend"
    path                      = "/src/frontend/k8"
    sync_interval_in_seconds  = 120
    retry_interval_in_seconds = 120
  }

  scope = "cluster"

  depends_on = [
    azurerm_kubernetes_cluster_extension.flux
  ]
}
